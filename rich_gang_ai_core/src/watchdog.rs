//! Heartbeat watchdog — the honest, library-sized version
//! (Tier-10, 2026-10-21).
//!
//! What this IS: a registry where named workers record heartbeats
//! (`Instant` timestamps), plus stale detection that returns a
//! report of which workers have not beaten within a threshold.
//!
//! What this is NOT: a supervisor. This crate is a library loaded
//! into the Flutter app via FFI; it owns no worker threads, so it
//! cannot respawn anything, and nothing here claims to. There is
//! also no hardware watchdog involved. A future host-side
//! supervisor (Kotlin foreground service) could consume
//! [`Watchdog::stale_workers`] and act on it — that consumer does
//! not exist in this build, and the build doc says so.
//!
//! Existing logging (logging.rs) already installs a panic hook on
//! Android that logs panics instead of silently dying; this module
//! complements it with liveness data, it does not replace it.

use std::collections::HashMap;
use std::sync::Mutex;
use std::time::{Duration, Instant};

/// A stale-detection report: who is stale, and how long since each
/// worker's last heartbeat at the moment of the check.
#[derive(Debug, Clone, PartialEq)]
pub struct StaleReport {
    pub worker: String,
    pub since_last_beat: Duration,
}

struct Inner {
    workers: HashMap<String, Instant>,
}

pub struct Watchdog {
    inner: Mutex<Inner>,
}

impl Watchdog {
    pub fn new() -> Self {
        Self {
            inner: Mutex::new(Inner {
                workers: HashMap::new(),
            }),
        }
    }

    /// Register a worker; its registration moment is its first
    /// heartbeat. Re-registering resets the timestamp.
    pub fn register_worker(&self, name: &str) {
        self.inner
            .lock()
            .expect("watchdog mutex poisoned")
            .workers
            .insert(name.to_string(), Instant::now());
    }

    /// Record a heartbeat for a registered worker. Returns false
    /// (and registers nothing) for an unknown name — a heartbeat
    /// from an unregistered worker is a caller bug, not liveness.
    pub fn heartbeat(&self, name: &str) -> bool {
        let mut inner = self.inner.lock().expect("watchdog mutex poisoned");
        match inner.workers.get_mut(name) {
            Some(t) => {
                *t = Instant::now();
                true
            }
            None => false,
        }
    }

    pub fn unregister_worker(&self, name: &str) -> bool {
        self.inner
            .lock()
            .expect("watchdog mutex poisoned")
            .workers
            .remove(name)
            .is_some()
    }

    pub fn worker_count(&self) -> usize {
        self.inner.lock().expect("watchdog mutex poisoned").workers.len()
    }

    /// Time since a worker's last heartbeat, or None if unknown.
    pub fn since_last_beat(&self, name: &str) -> Option<Duration> {
        self.inner
            .lock()
            .expect("watchdog mutex poisoned")
            .workers
            .get(name)
            .map(|t| t.elapsed())
    }

    /// Workers whose last heartbeat is older than `threshold`.
    /// Detection only — see the module docs for what does NOT
    /// happen next (no respawn exists in this crate).
    pub fn stale_workers(&self, threshold: Duration) -> Vec<StaleReport> {
        let inner = self.inner.lock().expect("watchdog mutex poisoned");
        let mut out: Vec<StaleReport> = inner
            .workers
            .iter()
            .map(|(name, t)| StaleReport {
                worker: name.clone(),
                since_last_beat: t.elapsed(),
            })
            .filter(|r| r.since_last_beat > threshold)
            .collect();
        out.sort_by(|a, b| a.worker.cmp(&b.worker));
        out
    }
}

impl Default for Watchdog {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn register_and_heartbeat() {
        let wd = Watchdog::new();
        wd.register_worker("dream");
        assert_eq!(wd.worker_count(), 1);
        assert!(wd.heartbeat("dream"));
        assert!(wd.since_last_beat("dream").is_some());
    }

    #[test]
    fn heartbeat_from_unknown_worker_is_rejected() {
        let wd = Watchdog::new();
        assert!(!wd.heartbeat("ghost"));
        assert_eq!(wd.worker_count(), 0);
        assert!(wd.since_last_beat("ghost").is_none());
    }

    #[test]
    fn fresh_workers_are_not_stale() {
        let wd = Watchdog::new();
        wd.register_worker("a");
        wd.register_worker("b");
        assert!(wd.stale_workers(Duration::from_secs(60)).is_empty());
    }

    #[test]
    fn stale_detection_reports_old_workers() {
        let wd = Watchdog::new();
        wd.register_worker("slow");
        std::thread::sleep(Duration::from_millis(30));
        let stale = wd.stale_workers(Duration::from_millis(10));
        assert_eq!(stale.len(), 1);
        assert_eq!(stale[0].worker, "slow");
        assert!(stale[0].since_last_beat >= Duration::from_millis(10));
        // A heartbeat clears staleness.
        assert!(wd.heartbeat("slow"));
        assert!(wd.stale_workers(Duration::from_millis(10)).is_empty());
    }

    #[test]
    fn unregister_removes_worker() {
        let wd = Watchdog::new();
        wd.register_worker("x");
        assert!(wd.unregister_worker("x"));
        assert!(!wd.unregister_worker("x"));
        assert_eq!(wd.worker_count(), 0);
    }
}
