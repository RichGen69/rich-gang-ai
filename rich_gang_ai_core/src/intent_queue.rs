//! Bounded FIFO intent queue — the honest "Mempool / Intent
//! Ingestion" stage of the arbitration pipeline (Execution Matrix,
//! 2026-10-31; see docs/EXECUTION_MATRIX_REALITY_2026-10-31.md).
//!
//! HONEST SCOPE: this is a fixed-capacity FIFO of intent strings
//! and nothing more. It ingests; it does not arbitrate, rank, or
//! execute. Arbitration already exists upstream in the app: the
//! Roundtable's sequential context passing plus Danny's
//! draft → critique → revise chain (see flutter_app/lib/core/
//! roundtable.dart and danny_chain.dart). This queue feeds that
//! pipeline; it is not a second pipeline, and no second pipeline
//! is invented here.
//!
//! Capacity is a caller policy, set at construction (the Daemon
//! reads it from the config key "intent_queue_capacity", default
//! 64 — a default, documented as such, never a measured figure).
//! Enqueue past capacity returns `Err("intent_queue_full")` and
//! the intent is NOT stored, NOT dropped silently, and NOT
//! reordered: the caller learns it was refused and keeps it.
//! Order is strictly FIFO: dequeue order always equals enqueue
//! order, which the tests assert.

use std::collections::VecDeque;

pub struct IntentQueue {
    capacity: usize,
    queue: VecDeque<String>,
}

impl IntentQueue {
    /// Capacity must be positive — a zero-capacity queue could never
    /// accept anything, so refusing to build one is the honest error.
    pub fn new(capacity: usize) -> Result<Self, String> {
        if capacity == 0 {
            return Err("intent_queue_capacity_must_be_positive".to_string());
        }
        Ok(Self {
            capacity,
            queue: VecDeque::new(),
        })
    }

    /// Enqueue one intent. Returns the new depth on success.
    pub fn enqueue(&mut self, intent: String) -> Result<usize, String> {
        if self.queue.len() >= self.capacity {
            return Err("intent_queue_full".to_string());
        }
        self.queue.push_back(intent);
        Ok(self.queue.len())
    }

    /// Dequeue the oldest intent, or None when empty.
    pub fn dequeue(&mut self) -> Option<String> {
        self.queue.pop_front()
    }

    pub fn len(&self) -> usize {
        self.queue.len()
    }

    pub fn is_empty(&self) -> bool {
        self.queue.is_empty()
    }

    pub fn capacity(&self) -> usize {
        self.capacity
    }

    pub fn is_full(&self) -> bool {
        self.queue.len() >= self.capacity
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn dequeue_order_is_exactly_enqueue_order() {
        let mut q = IntentQueue::new(4).unwrap();
        q.enqueue("first".into()).unwrap();
        q.enqueue("second".into()).unwrap();
        q.enqueue("third".into()).unwrap();
        assert_eq!(q.dequeue().as_deref(), Some("first"));
        assert_eq!(q.dequeue().as_deref(), Some("second"));
        assert_eq!(q.dequeue().as_deref(), Some("third"));
        assert_eq!(q.dequeue(), None);
        assert!(q.is_empty());
    }

    #[test]
    fn full_queue_refuses_explicitly_and_keeps_order() {
        let mut q = IntentQueue::new(2).unwrap();
        q.enqueue("a".into()).unwrap();
        q.enqueue("b".into()).unwrap();
        assert!(q.is_full());
        let err = q.enqueue("c".into()).err().expect("full must error");
        assert_eq!(err, "intent_queue_full");
        // The refused intent was not stored and nothing reordered.
        assert_eq!(q.len(), 2);
        assert_eq!(q.dequeue().as_deref(), Some("a"));
        assert_eq!(q.dequeue().as_deref(), Some("b"));
    }

    #[test]
    fn dequeue_frees_space_for_reenqueue() {
        let mut q = IntentQueue::new(1).unwrap();
        q.enqueue("x".into()).unwrap();
        assert!(q.enqueue("y".into()).is_err());
        assert_eq!(q.dequeue().as_deref(), Some("x"));
        assert_eq!(q.enqueue("y".into()).unwrap(), 1);
        assert_eq!(q.dequeue().as_deref(), Some("y"));
    }

    #[test]
    fn zero_capacity_is_rejected_at_construction() {
        let err = IntentQueue::new(0).err().expect("zero must error");
        assert_eq!(err, "intent_queue_capacity_must_be_positive");
    }
}
