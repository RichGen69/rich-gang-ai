# SPIKE V5-002 — rusqlite (v5 Tier 2: Affective SQLite)

Date: 2026-10-22. Authorised by Richard: "Start the v5 verification spikes, one crate at a time."
Location: `spikes/v5_002_rusqlite/` — isolated crate, NOT a dependency of `rich_gang_ai_core`.

## Verified before coding
- Cargo.lock confirms: rusqlite **0.32.1** + libsqlite3-sys **0.30.1** from crates.io; bundled SQLite **3.46.0** (reported by `rusqlite::version()` at runtime, test-proven).
- The `bundled` feature compiles SQLite's C source via the `cc` crate — the exact
  "harder spike" case flagged in SPIKE_V5_001: it needs a real C compiler for the
  Android target, not just the linker.
- APIs used, all real in 0.32.1: `Connection::open_in_memory / open`,
  `conn.execute`, `conn.prepare`, `query_row`, `query_map`, `params!`,
  `rusqlite::version()`. Upsert via `INSERT ... ON CONFLICT(key) DO UPDATE`.

## What was built in the spike
`PersistentStore`: file or in-memory SQLite with a `kv(key TEXT PRIMARY KEY, value TEXT NOT NULL)` table.
- `open_memory`, `open_file(path)` (file created if absent), `put` (parameter-bound,
  no string interpolation), `get` (missing key = `Ok(None)`, never a placeholder),
  `delete` (returns whether a row existed), `count`, `keys` (rowid order),
  `sqlite_version()` (the real linked version).
- Every failure is an explicit `Err`. WAL mode deliberately NOT assumed/enabled —
  spike uses default journal mode; journal/WAL choice is an integration decision.

## Results — real, reproduced in this session
- Host: `cargo test` — **8 passed, 0 failed**
  - put_get_roundtrip_is_real, missing_key_is_none_not_a_placeholder,
    overwrite_replaces_value, delete_reports_whether_row_existed,
    quoted_and_unicode_values_survive_exactly (payload `O'Brien said "hi" — it's
    100% fine'; DROP TABLE kv; --` round-trips byte-exact; table intact),
    file_store_persists_across_reopen (data survives connection drop + reopen),
    bad_sql_is_an_explicit_error, linked_sqlite_version_is_reported (3.46.0)
- Android target: `cargo check --target aarch64-linux-android` — **pass**
  (NDK r27, API 24 clang; `CC_aarch64_linux_android` set so the `cc` crate used
  the NDK compiler for the bundled C, `AR_aarch64_linux_android`=llvm-ar)
- Android target: `cargo build --target aarch64-linux-android` — **pass**;
  produced `libv5_002_rusqlite_spike.rlib` (1.2 MB debug) and, proving the C
  compiled for the right machine, `libsqlite3.a` containing `sqlite3.o` =
  **ELF 64-bit LSB relocatable, ARM aarch64** (verified with `file`).

## Verdict
**PASS — spike level only.**
rusqlite 0.32.1 (bundled SQLite 3.46.0) is viable for Tier 2: the bundled C source
compiles cleanly for aarch64-linux-android under the project's NDK r27/API 24
toolchain, and the store semantics (parameter binding, honest missing-key,
cross-reopen persistence) are test-proven on host.

## What this does NOT prove
- Not integrated into `rich_gang_ai_core`, not exposed over FFI, not in `libdaemon.so`
- Not device-verified (nothing ran on the A16 — no APK exists yet, other_tcp blocker unchanged)
- No WAL/journal-mode decision, no concurrency/multi-connection story, no migration story,
  no performance measurement, no latency claim
- Integration is a separate milestone requiring Richard's go-ahead: add rusqlite to the
  core Cargo.toml, add a persistent-store module behind the existing handle/FFI patterns,
  decide journal mode + file location, re-run cargo + flutter suites, rebuild + restage libdaemon.so

## Next spike in queue
003 — tokio (async runtime, needed by several v5 systems). Expect the hardest spike yet:
async on Android via JNI-adjacent threads needs care; the spike should prove a Tokio
runtime builds and runs on the target before any design commitment.
