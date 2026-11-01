# INTEGRATION V5 — rusqlite (Tier 2 persistent store)

Date: 2026-10-23. Authorised by Richard: "Integrate rusqlite into the
core now" (2026-10-23), following spike V5-002 PASS
(`docs/SPIKE_V5_002_RUSQLITE.md`). Mirrors the petgraph integration
pattern (`docs/INTEGRATION_V5_PETGRAPH_2026-10-22.md`): spike first,
integrate second, additive FFI, ABI unchanged, honest empty states.

## What was integrated

- **Dependency:** `rusqlite = { version = "0.32", features =
  ["bundled"] }` in `rich_gang_ai_core/Cargo.toml` — bundled SQLite
  3.46.0 compiled from C source (the Android build sets CC/CXX/AR
  for the target in `build_android.sh`, the pattern the spike proved).
- **Module:** `src/store.rs` — `SqlStore`, a single-table SQLite
  key-value store (`kv(key TEXT PRIMARY KEY, value TEXT NOT NULL)`)
  behind a `parking_lot::Mutex<Connection>`. All values are bound as
  SQL parameters; no string interpolation anywhere. A missing key
  returns `Ok(None)`; every database failure is an explicit `Err`
  with a `store_*_failed` prefix.
- **Daemon wiring:** `Daemon.store` field + `store()` accessor,
  built in `Daemon::new` from the config (below). A store failure
  fails daemon start — there is no silent degradation path.

## Design decisions (the ones the spike deferred)

- **Location:** config key `"store_path"`. A non-empty string opens
  a file-backed database at that path (created if absent). No key
  (the shipped `daemon_config.json` state) -> an **in-memory**
  database for the session, and the state surface reports
  `"persistent": false` so session storage is never mistaken for
  durable storage. A `"store_path"` that cannot be opened returns
  an explicit error and `rga_daemon_start` fails — test-asserted.
- **Journal mode:** file-backed stores run WAL
  (`PRAGMA journal_mode = WAL;`), the standard single-process
  embedded choice. The mode is **read back** from SQLite after open
  and reported as-is (`"wal"` / `"memory"`), never assumed.
- **No schema beyond `kv`, no migrations framework:** there is one
  table and `CREATE TABLE IF NOT EXISTS`. Anything richer waits for
  a real consumer design.

## FFI surface (additive, ABI stays 2)

- `rga_store_state` -> `{"persistent":bool,"journal_mode":...,
  "entries":N,"sqlite_version":"3.46.0"}` (or a `store_error` doc)
- `rga_store_put` -> `{"ok":true,"key":...}`
- `rga_store_get` -> `{"key":...,"found":true,"value":...}` or
  `{"key":...,"found":false}` — **no `value` field at all** when the
  key is missing; a placeholder is never invented
- `rga_store_delete` -> `{"key":...,"existed":bool}`

Dart bindings in `NativeBridge`: `storeState()`, `storePut()`,
`storeGet()`, `storeDelete()`, following the existing ownership
contract (Rust strings freed via `rga_string_free`, inputs freed in
`finally`). No Kotlin/JNI bindings and no UI surface yet — same
posture as the petgraph integration at this step.

## Verification (this session, VM-only)

- `cargo test` — **62 passed, 0 failed** (baseline 51 post-petgraph
  + 11 new: 9 `store` unit tests — roundtrip, missing-key honesty,
  overwrite, delete semantics, quote/unicode payload byte-exactness,
  in-memory reports `persistent:false`/`journal_mode:"memory"`,
  file store persists across reopen in WAL, config default +
  unopenable-path error, linked SQLite version — and 2 FFI tests:
  full put/get/delete roundtrip across the C boundary with
  `found:false` shape asserted, and daemon-start failure on an
  unopenable `store_path`).
- `flutter test` — **43 passed, 0 failed**; `flutter analyze` —
  **clean** under the permanently enforced strict options.
- `libdaemon.so` rebuilt for aarch64-linux-android and restaged:
  SHA-256 `26bab703c168500b179fff766d56197ea3b807993c702ca58fd954394b59dc02`,
  2,720,312 bytes; the four `rga_store_*` exports present (25
  `rga_*`/JNI exports total, up from 21); every LOAD segment
  Align `0x4000`.

## What this does NOT prove

- **Not device-verified.** No APK exists (the `other_tcp` build
  permission blocker is unchanged), so the store has never run on
  the A16; Android evidence is cross-compile + symbol verification.
- **No shipped consumer yet.** Nothing in the app writes to the
  store today: the shipped `daemon_config.json` has no `store_path`
  (so a booted daemon runs the in-memory store), and choosing the
  on-device file location (app files directory) belongs to the app
  wiring step, as does any UI. The capability is integrated and
  FFI-reachable; it is not yet used by a feature.
- No concurrency story beyond the single mutex-guarded connection,
  no backup/restore, no performance measurement, no latency claim.
