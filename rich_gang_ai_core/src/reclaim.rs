//! Bounded store sweep — the honest form of the Gemini
//! "Autophagic Garbage Reclamation" claim (Execution Matrix,
//! 2026-10-31; see docs/EXECUTION_MATRIX_REALITY_2026-10-31.md).
//!
//! HONEST SCOPE, STATED PLAINLY: there is no "necrotic thread
//! stack" and no "byte primitive pool" in this daemon, and this
//! module invents neither. What actually exists is the rusqlite
//! key-value store (store.rs), whose schema is `kv(key, value)`
//! with NO timestamp column — so time-based expiry is impossible
//! to prove from the schema and is NOT built. Automatic
//! time-based purging is documented as not built, not faked.
//!
//! What this module does, all from real store state:
//! * `report` — entry count, persistence, journal mode, and the
//!   key list (rowid order), straight from SQLite.
//! * `delete_named` — deletes ONLY the keys the caller names and
//!   reports, per key, whether it was actually deleted or was
//!   already missing. Nothing else is touched.
//! * `trim_to_cap` — enforces a caller-supplied cap by deleting
//!   the OLDEST entries (rowid order) beyond the cap and reporting
//!   exactly which keys were removed and how many remain. The cap
//!   is caller policy, never a default invented here; a cap of
//!   zero is an explicit error (deleting everything must be an
//!   explicit named delete, not a side effect of "trim to 0").
//!
//! The memory-mapped ring's capacity accounting needs no new code:
//! `rga_ring_state` already reports real capacity, head, tail,
//! pending bytes and pending messages from ring_ipc.rs.

use crate::store::SqlStore;

/// Real store state, nothing derived or estimated.
pub struct StoreReport {
    pub entries: usize,
    pub persistent: bool,
    pub journal_mode: String,
    pub keys: Vec<String>,
}

pub struct DeleteReport {
    pub deleted: Vec<String>,
    pub missing: Vec<String>,
}

pub struct TrimReport {
    pub removed: Vec<String>,
    pub remaining: usize,
}

pub fn report(store: &SqlStore) -> Result<StoreReport, String> {
    Ok(StoreReport {
        entries: store.count()?,
        persistent: store.is_persistent(),
        journal_mode: store.journal_mode().to_string(),
        keys: store.keys()?,
    })
}

/// Delete exactly the named keys. Missing keys are reported, not
/// treated as errors and not silently ignored.
pub fn delete_named(store: &SqlStore, keys: &[String]) -> Result<DeleteReport, String> {
    let mut deleted = Vec::new();
    let mut missing = Vec::new();
    for key in keys {
        if store.delete(key)? {
            deleted.push(key.clone());
        } else {
            missing.push(key.clone());
        }
    }
    Ok(DeleteReport { deleted, missing })
}

/// Enforce `cap` by deleting oldest-first (rowid order) entries
/// beyond it. No-op when the store is already at or under cap.
pub fn trim_to_cap(store: &SqlStore, cap: usize) -> Result<TrimReport, String> {
    if cap == 0 {
        return Err("reclaim_cap_must_be_positive".to_string());
    }
    let keys = store.keys()?;
    if keys.len() <= cap {
        return Ok(TrimReport {
            removed: Vec::new(),
            remaining: keys.len(),
        });
    }
    let excess = keys.len() - cap;
    let mut removed = Vec::new();
    for key in keys.iter().take(excess) {
        // Keys came from the store a moment ago; a false return here
        // would mean concurrent modification, so it is an error rather
        // than a silent skip.
        if !store.delete(key)? {
            return Err(format!("reclaim_key_vanished: {key}"));
        }
        removed.push(key.clone());
    }
    Ok(TrimReport {
        removed,
        remaining: store.count()?,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    fn seeded() -> SqlStore {
        let s = SqlStore::open_memory().unwrap();
        s.put("oldest", "1").unwrap();
        s.put("middle", "2").unwrap();
        s.put("newest", "3").unwrap();
        s
    }

    #[test]
    fn report_counts_real_entries_and_lists_real_keys() {
        let s = seeded();
        let r = report(&s).unwrap();
        assert_eq!(r.entries, 3);
        assert!(!r.persistent);
        assert_eq!(r.journal_mode, "memory");
        assert_eq!(r.keys, vec!["oldest", "middle", "newest"]);
    }

    #[test]
    fn delete_named_touches_only_named_keys_and_reports_missing() {
        let s = seeded();
        let r = delete_named(&s, &["middle".to_string(), "ghost".to_string()]).unwrap();
        assert_eq!(r.deleted, vec!["middle".to_string()]);
        assert_eq!(r.missing, vec!["ghost".to_string()]);
        assert_eq!(s.get("middle").unwrap(), None);
        assert_eq!(s.get("oldest").unwrap(), Some("1".into()));
        assert_eq!(s.get("newest").unwrap(), Some("3".into()));
    }

    #[test]
    fn trim_to_cap_removes_oldest_first_and_reports_exactly() {
        let s = seeded();
        let r = trim_to_cap(&s, 2).unwrap();
        assert_eq!(r.removed, vec!["oldest".to_string()]);
        assert_eq!(r.remaining, 2);
        assert_eq!(s.get("oldest").unwrap(), None);
        assert_eq!(s.get("middle").unwrap(), Some("2".into()));
        assert_eq!(s.get("newest").unwrap(), Some("3".into()));
    }

    #[test]
    fn trim_at_or_over_count_is_a_no_op() {
        let s = seeded();
        let r = trim_to_cap(&s, 3).unwrap();
        assert!(r.removed.is_empty());
        assert_eq!(r.remaining, 3);
        let r = trim_to_cap(&s, 99).unwrap();
        assert!(r.removed.is_empty());
        assert_eq!(r.remaining, 3);
    }

    #[test]
    fn trim_to_zero_is_an_explicit_error_not_a_wipe() {
        let s = seeded();
        let err = trim_to_cap(&s, 0).err().expect("zero cap must error");
        assert_eq!(err, "reclaim_cap_must_be_positive");
        // Nothing was deleted by the refused operation.
        assert_eq!(s.count().unwrap(), 3);
    }
}
