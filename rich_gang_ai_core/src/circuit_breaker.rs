//! Synchronous 3-state circuit breaker (Tier-10, 2026-10-21).
//!
//! Scope, honestly: this is a state machine in the Rust core. It
//! records outcomes the CALLER reports (success / failure / observed
//! latency) and answers `can_execute()` with an O(1) state check —
//! a few atomic/mutex operations, no I/O, no allocation. No latency
//! benchmark has been measured for it in this build, so no
//! millisecond figure is claimed for the transition anywhere.
//!
//! The core is not a Tokio application and this module deliberately
//! uses only `std` (`Mutex`, `Instant`), matching the existing core
//! style. It does not itself call any cloud API, probe any network,
//! or reroute traffic — wiring it to a caller is that caller's job.
//! (In this build the live cloud->Ollama failover lives in the Dart
//! InferenceRouter; this breaker is the Rust-side primitive with
//! unit tests, not a second hidden router.)

use std::sync::Mutex;
use std::time::{Duration, Instant};

/// Latency above this is treated as a failure signal by
/// [`CircuitBreaker::record_latency`]. The 250 ms threshold is the
/// value Richard supplied in the Tier-10 specification.
pub const LATENCY_FAILURE_THRESHOLD_MS: u64 = 250;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CircuitState {
    /// Healthy: cloud execution allowed.
    Closed,
    /// Tripped: cloud execution blocked until the recovery timeout.
    Open,
    /// Recovery timeout elapsed: one trial execution is allowed;
    /// its outcome decides Closed (success) vs Open (failure).
    HalfOpen,
}

struct Inner {
    state: CircuitState,
    failure_count: usize,
    opened_at: Option<Instant>,
}

pub struct CircuitBreaker {
    failure_threshold: usize,
    recovery_timeout: Duration,
    inner: Mutex<Inner>,
}

impl CircuitBreaker {
    pub fn new(failure_threshold: usize, recovery_timeout: Duration) -> Self {
        Self {
            failure_threshold: failure_threshold.max(1),
            recovery_timeout,
            inner: Mutex::new(Inner {
                state: CircuitState::Closed,
                failure_count: 0,
                opened_at: None,
            }),
        }
    }

    pub fn state(&self) -> CircuitState {
        self.inner.lock().expect("circuit breaker mutex poisoned").state
    }

    pub fn failure_count(&self) -> usize {
        self.inner
            .lock()
            .expect("circuit breaker mutex poisoned")
            .failure_count
    }

    /// O(1) state check. Transitions Open -> HalfOpen when the
    /// recovery timeout has elapsed and allows that trial call.
    pub fn can_execute(&self) -> bool {
        let mut inner = self.inner.lock().expect("circuit breaker mutex poisoned");
        match inner.state {
            CircuitState::Closed | CircuitState::HalfOpen => true,
            CircuitState::Open => {
                let elapsed = inner.opened_at.map(|t| t.elapsed());
                if elapsed.map(|e| e >= self.recovery_timeout).unwrap_or(false) {
                    inner.state = CircuitState::HalfOpen;
                    true
                } else {
                    false
                }
            }
        }
    }

    pub fn record_success(&self) {
        let mut inner = self.inner.lock().expect("circuit breaker mutex poisoned");
        inner.failure_count = 0;
        if inner.state == CircuitState::HalfOpen {
            inner.state = CircuitState::Closed;
            inner.opened_at = None;
        }
    }

    pub fn record_failure(&self) {
        let mut inner = self.inner.lock().expect("circuit breaker mutex poisoned");
        inner.failure_count += 1;
        if inner.state == CircuitState::HalfOpen
            || inner.failure_count >= self.failure_threshold
        {
            inner.state = CircuitState::Open;
            inner.opened_at = Some(Instant::now());
        }
    }

    /// Record an observed cloud latency. A latency strictly above
    /// [`LATENCY_FAILURE_THRESHOLD_MS`] counts as a failure signal;
    /// anything at or below it counts as a success.
    pub fn record_latency(&self, latency_ms: u64) {
        if latency_ms > LATENCY_FAILURE_THRESHOLD_MS {
            self.record_failure();
        } else {
            self.record_success();
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn breaker(threshold: usize, timeout: Duration) -> CircuitBreaker {
        CircuitBreaker::new(threshold, timeout)
    }

    #[test]
    fn closed_allows_execution() {
        let cb = breaker(3, Duration::from_secs(60));
        assert_eq!(cb.state(), CircuitState::Closed);
        assert!(cb.can_execute());
    }

    #[test]
    fn trips_after_threshold_failures() {
        let cb = breaker(3, Duration::from_secs(60));
        cb.record_failure();
        cb.record_failure();
        assert_eq!(cb.state(), CircuitState::Closed);
        assert!(cb.can_execute());
        cb.record_failure();
        assert_eq!(cb.state(), CircuitState::Open);
        assert_eq!(cb.failure_count(), 3);
    }

    #[test]
    fn open_blocks_execution() {
        let cb = breaker(1, Duration::from_secs(60));
        cb.record_failure();
        assert_eq!(cb.state(), CircuitState::Open);
        assert!(!cb.can_execute());
    }

    #[test]
    fn half_open_after_recovery_timeout() {
        let cb = breaker(1, Duration::from_millis(10));
        cb.record_failure();
        assert!(!cb.can_execute());
        std::thread::sleep(Duration::from_millis(30));
        assert!(cb.can_execute());
        assert_eq!(cb.state(), CircuitState::HalfOpen);
    }

    #[test]
    fn success_in_half_open_closes() {
        let cb = breaker(1, Duration::from_millis(10));
        cb.record_failure();
        std::thread::sleep(Duration::from_millis(30));
        assert!(cb.can_execute());
        cb.record_success();
        assert_eq!(cb.state(), CircuitState::Closed);
        assert_eq!(cb.failure_count(), 0);
        assert!(cb.can_execute());
    }

    #[test]
    fn failure_in_half_open_reopens() {
        let cb = breaker(1, Duration::from_millis(10));
        cb.record_failure();
        std::thread::sleep(Duration::from_millis(30));
        assert!(cb.can_execute());
        cb.record_failure();
        assert_eq!(cb.state(), CircuitState::Open);
        assert!(!cb.can_execute());
    }

    #[test]
    fn latency_spike_counts_as_failure() {
        let cb = breaker(2, Duration::from_secs(60));
        cb.record_latency(251);
        assert_eq!(cb.failure_count(), 1);
        assert_eq!(cb.state(), CircuitState::Closed);
        cb.record_latency(900);
        assert_eq!(cb.state(), CircuitState::Open);
    }

    #[test]
    fn latency_at_or_below_threshold_counts_as_success() {
        let cb = breaker(2, Duration::from_secs(60));
        cb.record_latency(250);
        cb.record_latency(12);
        assert_eq!(cb.failure_count(), 0);
        assert_eq!(cb.state(), CircuitState::Closed);
    }
}
