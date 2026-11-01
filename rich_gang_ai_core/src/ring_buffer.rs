//! Atomic ring buffer (Tier-10, 2026-10-21) — named honestly.
//!
//! This is an atomic head/tail ring buffer with SLOT-LOCKED storage:
//! `head`/`tail`/`len` are `std` atomics, and each slot is a
//! `Mutex<Option<T>>`. It is therefore NOT lock-free and NOT
//! zero-copy, and it is not described as such anywhere: a genuinely
//! lock-free safe implementation needs a lock-free slot protocol
//! (e.g. per-slot sequence numbers with `UnsafeCell`, or the
//! crossbeam crate), neither of which is used here — crossbeam is
//! not a dependency of this crate and no `unsafe` was introduced
//! for this module.
//!
//! Semantics: bounded, power-of-two capacity. `try_push` fails with
//! the value back when full (nothing is overwritten, nothing is
//! silently dropped); `try_pop` returns `None` when empty. FIFO
//! order. Safe for concurrent producers/consumers at the API level
//! (the slot mutexes serialise individual slot access), with the
//! usual caveat that check-then-act sequences across calls are the
//! caller's responsibility.
//!
//! No content hashing is implemented: `sha2` is not a dependency of
//! this crate, so no SHA-256 state-verification claim is made.

use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::Mutex;

pub struct AtomicRingBuffer<T> {
    slots: Vec<Mutex<Option<T>>>,
    mask: usize,
    head: AtomicUsize, // next pop index (monotonic)
    tail: AtomicUsize, // next push index (monotonic)
    len: AtomicUsize,
}

impl<T> AtomicRingBuffer<T> {
    /// Capacity is rounded UP to the next power of two (minimum 1)
    /// so index wrapping is a mask operation.
    pub fn new(capacity: usize) -> Self {
        let cap = capacity.max(1).next_power_of_two();
        let mut slots = Vec::with_capacity(cap);
        for _ in 0..cap {
            slots.push(Mutex::new(None));
        }
        Self {
            slots,
            mask: cap - 1,
            head: AtomicUsize::new(0),
            tail: AtomicUsize::new(0),
            len: AtomicUsize::new(0),
        }
    }

    pub fn capacity(&self) -> usize {
        self.slots.len()
    }

    pub fn len(&self) -> usize {
        self.len.load(Ordering::SeqCst)
    }

    pub fn is_empty(&self) -> bool {
        self.len() == 0
    }

    pub fn is_full(&self) -> bool {
        self.len() == self.capacity()
    }

    /// Push one item. `Err(value)` — the item back, unmodified —
    /// when the buffer is full.
    pub fn try_push(&self, value: T) -> Result<(), T> {
        if self.is_full() {
            return Err(value);
        }
        let idx = self.tail.fetch_add(1, Ordering::SeqCst) & self.mask;
        let mut slot = self.slots[idx].lock().expect("ring slot mutex poisoned");
        if slot.is_some() {
            // Can only happen if a concurrent push raced us to the
            // same slot after the length check; report full honestly
            // rather than overwriting live data.
            drop(slot);
            self.tail.fetch_sub(1, Ordering::SeqCst);
            return Err(value);
        }
        *slot = Some(value);
        self.len.fetch_add(1, Ordering::SeqCst);
        Ok(())
    }

    /// Pop the oldest item, or `None` when empty.
    pub fn try_pop(&self) -> Option<T> {
        if self.is_empty() {
            return None;
        }
        let idx = self.head.fetch_add(1, Ordering::SeqCst) & self.mask;
        let mut slot = self.slots[idx].lock().expect("ring slot mutex poisoned");
        let out = slot.take();
        if out.is_some() {
            self.len.fetch_sub(1, Ordering::SeqCst);
        } else {
            // Raced with another consumer; keep the counter honest.
            self.head.fetch_sub(1, Ordering::SeqCst);
        }
        out
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn empty_pop_returns_none() {
        let rb: AtomicRingBuffer<u32> = AtomicRingBuffer::new(4);
        assert!(rb.is_empty());
        assert_eq!(rb.try_pop(), None);
    }

    #[test]
    fn fifo_order() {
        let rb = AtomicRingBuffer::new(4);
        assert!(rb.try_push(1).is_ok());
        assert!(rb.try_push(2).is_ok());
        assert!(rb.try_push(3).is_ok());
        assert_eq!(rb.try_pop(), Some(1));
        assert_eq!(rb.try_pop(), Some(2));
        assert_eq!(rb.try_pop(), Some(3));
        assert_eq!(rb.try_pop(), None);
    }

    #[test]
    fn full_push_returns_value_and_does_not_overwrite() {
        let rb = AtomicRingBuffer::new(2);
        assert!(rb.try_push(10).is_ok());
        assert!(rb.try_push(20).is_ok());
        assert!(rb.is_full());
        assert_eq!(rb.try_push(30), Err(30));
        // The queued items are untouched.
        assert_eq!(rb.try_pop(), Some(10));
        assert_eq!(rb.try_pop(), Some(20));
    }

    #[test]
    fn wraps_around() {
        let rb = AtomicRingBuffer::new(4);
        for round in 0..3u32 {
            for i in 0..4u32 {
                assert!(rb.try_push(round * 10 + i).is_ok());
            }
            for i in 0..4u32 {
                assert_eq!(rb.try_pop(), Some(round * 10 + i));
            }
        }
        assert!(rb.is_empty());
    }

    #[test]
    fn capacity_rounds_up_to_power_of_two() {
        let rb: AtomicRingBuffer<u8> = AtomicRingBuffer::new(3);
        assert_eq!(rb.capacity(), 4);
        let rb: AtomicRingBuffer<u8> = AtomicRingBuffer::new(1);
        assert_eq!(rb.capacity(), 1);
    }

    #[test]
    fn interleaved_push_pop_keeps_count() {
        let rb = AtomicRingBuffer::new(4);
        assert!(rb.try_push(1).is_ok());
        assert!(rb.try_push(2).is_ok());
        assert_eq!(rb.try_pop(), Some(1));
        assert!(rb.try_push(3).is_ok());
        assert_eq!(rb.len(), 2);
        assert_eq!(rb.try_pop(), Some(2));
        assert_eq!(rb.try_pop(), Some(3));
        assert_eq!(rb.len(), 0);
    }
}
