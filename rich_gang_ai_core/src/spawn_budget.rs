//! Bounded agent-task budget — the honest form of the Gemini
//! "Recursive Bounded Spawning (N ≤ 3)" claim (Execution Matrix,
//! 2026-10-31; see docs/EXECUTION_MATRIX_REALITY_2026-10-31.md).
//!
//! HONEST SCOPE: this is a counting semaphore with exactly three
//! slots, nothing more. It does not spawn processes, threads, or
//! agents; it gates how many concurrent agent *tasks* a caller may
//! hold at once. The bound is the myth's own N ≤ 3, adopted as a
//! policy constant — not a measured throughput figure, and no
//! throughput is claimed anywhere.
//!
//! Failure is explicit, never silent: acquiring past the bound
//! returns `Err("spawn_budget_exhausted")` and the task is NOT
//! queued, NOT dropped silently, and NOT run over the bound.
//! Releasing a slot that is not held is an explicit error, never
//! a silent no-op, so a double release cannot inflate capacity.

/// Maximum concurrent agent tasks. The myth's N ≤ 3, as policy.
pub const MAX_CONCURRENT_TASKS: usize = 3;

/// Three-slot budget. Not thread-safe on its own — the Daemon holds
/// it behind a mutex (see lib.rs).
pub struct SpawnBudget {
    held: [bool; MAX_CONCURRENT_TASKS],
}

impl SpawnBudget {
    pub fn new() -> Self {
        Self {
            held: [false; MAX_CONCURRENT_TASKS],
        }
    }

    /// Take a free slot. Returns the slot id (0..3).
    pub fn acquire(&mut self) -> Result<usize, String> {
        for (slot, taken) in self.held.iter_mut().enumerate() {
            if !*taken {
                *taken = true;
                return Ok(slot);
            }
        }
        Err("spawn_budget_exhausted".to_string())
    }

    /// Return a slot. Errors on an out-of-range slot and on a slot
    /// that is not currently held.
    pub fn release(&mut self, slot: usize) -> Result<(), String> {
        let Some(taken) = self.held.get_mut(slot) else {
            return Err(format!("spawn_slot_invalid: {slot}"));
        };
        if !*taken {
            return Err(format!("spawn_slot_not_held: {slot}"));
        }
        *taken = false;
        Ok(())
    }

    pub fn held_count(&self) -> usize {
        self.held.iter().filter(|t| **t).count()
    }

    pub fn free_slots(&self) -> Vec<usize> {
        self.held
            .iter()
            .enumerate()
            .filter(|(_, t)| !**t)
            .map(|(slot, _)| slot)
            .collect()
    }
}

impl Default for SpawnBudget {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn three_acquires_succeed_fourth_is_explicit_error() {
        let mut b = SpawnBudget::new();
        assert_eq!(b.acquire().unwrap(), 0);
        assert_eq!(b.acquire().unwrap(), 1);
        assert_eq!(b.acquire().unwrap(), 2);
        assert_eq!(b.held_count(), 3);
        assert_eq!(
            b.acquire().err().as_deref(),
            Some("spawn_budget_exhausted")
        );
        // Nothing was queued or silently dropped: still exactly 3 held.
        assert_eq!(b.held_count(), 3);
        assert!(b.free_slots().is_empty());
    }

    #[test]
    fn release_frees_exactly_that_slot_for_reacquire() {
        let mut b = SpawnBudget::new();
        let s0 = b.acquire().unwrap();
        let _ = b.acquire().unwrap();
        let _ = b.acquire().unwrap();
        b.release(s0).unwrap();
        assert_eq!(b.held_count(), 2);
        assert_eq!(b.free_slots(), vec![s0]);
        assert_eq!(b.acquire().unwrap(), s0);
        assert_eq!(b.held_count(), 3);
    }

    #[test]
    fn double_release_and_invalid_slot_are_errors() {
        let mut b = SpawnBudget::new();
        let s = b.acquire().unwrap();
        b.release(s).unwrap();
        let err = b.release(s).err().expect("double release must error");
        assert!(err.contains("spawn_slot_not_held"), "got: {err}");
        let err = b.release(99).err().expect("invalid slot must error");
        assert!(err.contains("spawn_slot_invalid"), "got: {err}");
        // Capacity was not inflated by the bad releases.
        assert_eq!(b.held_count(), 0);
        assert_eq!(b.free_slots(), vec![0, 1, 2]);
    }
}
