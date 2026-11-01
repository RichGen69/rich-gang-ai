//! Persistent key-value store (v5 Tier 2, integrated 2026-10-23 from
//! spike `spikes/v5_002_rusqlite/` — see docs/SPIKE_V5_002_RUSQLITE.md
//! and docs/INTEGRATION_V5_RUSQLITE_2026-10-23.md).
//!
//! HONEST SCOPE: this is a single-table SQLite key-value store
//! (rusqlite, bundled SQLite) behind a mutex — nothing more. It
//! persists exactly what callers put into it; it fabricates nothing.
//! A missing key reads back as `Ok(None)` (FFI: `"found": false`),
//! never a placeholder. Every database failure is an explicit `Err`.
//!
//! Location is config-driven, like the fact table and the topology
//! (Richard's data rules): the daemon config key `"store_path"` names
//! the database file. No `"store_path"` key -> an in-memory database
//! for this daemon session, and the state surface reports
//! `"persistent": false` so nothing downstream can mistake session
//! storage for durable storage. A `"store_path"` that cannot be
//! opened FAILS daemon start (an explicit error) rather than silently
//! falling back to memory — silent fallback would fake persistence.
//!
//! Journal decision (deferred by the spike, made here): file-backed
//! stores run in WAL mode (`PRAGMA journal_mode = WAL;`), the
//! standard choice for a single-process embedded database — one
//! writer, crash-safe commits. The mode is read back from SQLite
//! after opening and reported as-is; it is never assumed. In-memory
//! databases keep SQLite's default ("memory") journal.

use parking_lot::Mutex;
use rusqlite::{params, Connection};

pub struct SqlStore {
    conn: Mutex<Connection>,
    persistent: bool,
    journal_mode: String,
}

impl SqlStore {
    /// In-memory store (no "store_path" in config, or tests).
    pub fn open_memory() -> Result<Self, String> {
        let conn = Connection::open_in_memory()
            .map_err(|e| format!("store_open_failed: {e}"))?;
        Self::init(conn, false)
    }

    /// File-backed store at `path` (created if absent), WAL journal.
    pub fn open_file(path: &str) -> Result<Self, String> {
        let conn = Connection::open(path)
            .map_err(|e| format!("store_open_failed: {path}: {e}"))?;
        Self::init(conn, true)
    }

    /// Build from the daemon config: "store_path" (non-empty string)
    /// -> file store; anything else -> in-memory session store.
    pub fn from_config(config: &serde_json::Value) -> Result<Self, String> {
        match config.get("store_path").and_then(|v| v.as_str()) {
            Some(path) if !path.trim().is_empty() => Self::open_file(path),
            _ => Self::open_memory(),
        }
    }

    fn init(conn: Connection, persistent: bool) -> Result<Self, String> {
        conn.execute(
            "CREATE TABLE IF NOT EXISTS kv (
                 key   TEXT PRIMARY KEY,
                 value TEXT NOT NULL
             )",
            [],
        )
        .map_err(|e| format!("store_schema_failed: {e}"))?;
        if persistent {
            conn.execute_batch("PRAGMA journal_mode = WAL;")
                .map_err(|e| format!("store_journal_failed: {e}"))?;
        }
        // Read the mode back — report what SQLite actually runs, never
        // what was requested.
        let journal_mode: String = conn
            .query_row("PRAGMA journal_mode;", [], |r| r.get(0))
            .map_err(|e| format!("store_journal_read_failed: {e}"))?;
        Ok(Self {
            conn: Mutex::new(conn),
            persistent,
            journal_mode,
        })
    }

    pub fn is_persistent(&self) -> bool {
        self.persistent
    }

    pub fn journal_mode(&self) -> &str {
        &self.journal_mode
    }

    /// Insert or replace. Values are bound as parameters — no string
    /// interpolation anywhere in this module.
    pub fn put(&self, key: &str, value: &str) -> Result<(), String> {
        self.conn
            .lock()
            .execute(
                "INSERT INTO kv (key, value) VALUES (?1, ?2)
                 ON CONFLICT(key) DO UPDATE SET value = excluded.value",
                params![key, value],
            )
            .map_err(|e| format!("store_put_failed: {e}"))?;
        Ok(())
    }

    /// Read. Missing key is `Ok(None)` — an honest answer.
    pub fn get(&self, key: &str) -> Result<Option<String>, String> {
        let conn = self.conn.lock();
        let mut stmt = conn
            .prepare("SELECT value FROM kv WHERE key = ?1")
            .map_err(|e| format!("store_get_failed: {e}"))?;
        let mut rows = stmt
            .query(params![key])
            .map_err(|e| format!("store_get_failed: {e}"))?;
        match rows.next().map_err(|e| format!("store_get_failed: {e}"))? {
            Some(row) => Ok(Some(
                row.get(0).map_err(|e| format!("store_get_failed: {e}"))?,
            )),
            None => Ok(None),
        }
    }

    /// Delete. Returns whether a row actually existed.
    pub fn delete(&self, key: &str) -> Result<bool, String> {
        let n = self
            .conn
            .lock()
            .execute("DELETE FROM kv WHERE key = ?1", params![key])
            .map_err(|e| format!("store_delete_failed: {e}"))?;
        Ok(n == 1)
    }

    pub fn count(&self) -> Result<usize, String> {
        let n: i64 = self
            .conn
            .lock()
            .query_row("SELECT COUNT(*) FROM kv", [], |r| r.get(0))
            .map_err(|e| format!("store_count_failed: {e}"))?;
        Ok(n as usize)
    }

    /// Keys in insertion-stable order (rowid order).
    pub fn keys(&self) -> Result<Vec<String>, String> {
        let conn = self.conn.lock();
        let mut stmt = conn
            .prepare("SELECT key FROM kv ORDER BY rowid")
            .map_err(|e| format!("store_keys_failed: {e}"))?;
        let rows = stmt
            .query_map([], |r| r.get(0))
            .map_err(|e| format!("store_keys_failed: {e}"))?;
        rows.collect::<Result<Vec<String>, _>>()
            .map_err(|e| format!("store_keys_failed: {e}"))
    }

    /// The SQLite library version actually linked — checkable fact.
    pub fn sqlite_version() -> String {
        rusqlite::version().to_string()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::env;
    use std::fs;

    #[test]
    fn put_get_roundtrip_is_real() {
        let s = SqlStore::open_memory().unwrap();
        s.put("agent:dan", "{\"mood\":\"ready\"}").unwrap();
        assert_eq!(
            s.get("agent:dan").unwrap(),
            Some("{\"mood\":\"ready\"}".into())
        );
    }

    #[test]
    fn missing_key_is_none_not_a_placeholder() {
        let s = SqlStore::open_memory().unwrap();
        assert_eq!(s.get("nobody").unwrap(), None);
    }

    #[test]
    fn overwrite_replaces_value() {
        let s = SqlStore::open_memory().unwrap();
        s.put("k", "v1").unwrap();
        s.put("k", "v2").unwrap();
        assert_eq!(s.get("k").unwrap(), Some("v2".into()));
        assert_eq!(s.count().unwrap(), 1);
    }

    #[test]
    fn delete_reports_whether_row_existed() {
        let s = SqlStore::open_memory().unwrap();
        assert!(!s.delete("ghost").unwrap());
        s.put("k", "v").unwrap();
        assert!(s.delete("k").unwrap());
        assert_eq!(s.get("k").unwrap(), None);
    }

    #[test]
    fn quoted_and_unicode_values_survive_exactly() {
        let s = SqlStore::open_memory().unwrap();
        let tricky = "O'Brien said \"hi\" — it's 100% fine'; DROP TABLE kv; --";
        s.put("tricky", tricky).unwrap();
        assert_eq!(s.get("tricky").unwrap(), Some(tricky.into()));
        assert_eq!(s.count().unwrap(), 1);
    }

    #[test]
    fn memory_store_reports_itself_not_persistent() {
        let s = SqlStore::open_memory().unwrap();
        assert!(!s.is_persistent());
        assert_eq!(s.journal_mode(), "memory");
    }

    #[test]
    fn file_store_persists_across_reopen_in_wal() {
        let dir = env::temp_dir().join("rga_core_store_test");
        fs::create_dir_all(&dir).unwrap();
        let path = dir.join("probe.db");
        for suffix in ["", "-wal", "-shm"] {
            let _ = fs::remove_file(format!("{}{suffix}", path.display()));
        }
        let path_s = path.to_str().unwrap().to_string();
        {
            let s = SqlStore::open_file(&path_s).unwrap();
            assert!(s.is_persistent());
            assert_eq!(s.journal_mode(), "wal");
            s.put("daemon:uptime_s", "86400").unwrap();
        }
        {
            let s = SqlStore::open_file(&path_s).unwrap();
            assert_eq!(s.get("daemon:uptime_s").unwrap(), Some("86400".into()));
            assert_eq!(s.keys().unwrap(), vec!["daemon:uptime_s".to_string()]);
        }
        for suffix in ["", "-wal", "-shm"] {
            let _ = fs::remove_file(format!("{}{suffix}", path.display()));
        }
    }

    #[test]
    fn from_config_defaults_to_memory_and_honours_store_path() {
        let s = SqlStore::from_config(&serde_json::json!({})).unwrap();
        assert!(!s.is_persistent());
        // A store_path that cannot be opened is an explicit error,
        // never a silent fall back to memory.
        let err = SqlStore::from_config(
            &serde_json::json!({ "store_path": "/no/such/dir/rga.db" }),
        )
        .err()
        .expect("unopenable path must error");
        assert!(err.contains("store_open_failed"), "got: {err}");
    }

    #[test]
    fn linked_sqlite_version_is_reported() {
        let v = SqlStore::sqlite_version();
        assert!(!v.is_empty());
        assert!(v.chars().next().unwrap().is_ascii_digit());
    }
}
