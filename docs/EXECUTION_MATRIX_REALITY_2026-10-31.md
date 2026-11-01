# Execution Matrix — Myth → Reality Mapping — 2026-10-31

Source: Gemini "Execution Matrix" text Richard supplied via
screenshots on 2026-10-31 (a generated spec document, not a build
record). Richard's order: make it real code, not "try". Real here
means honest: every myth claim below is either a working
component with test evidence, a bounded honest equivalent, or a
documented rejection. No myth language is presented as fact
anywhere in this document, and nothing here changes the approved
sales copy.

Standing rules applied throughout: no mock data, no mock math,
no hallucination; Rust rusqlite is the single conversation store
(Room FTS5 stays parked and unwired, locked 2026-10-30); human
approval is never removed (Richard is the human approval); the
roster's single source of truth is characters.json; additive only
to the verified core (ABI stays 2); no new cloud dependencies,
no API keys, no spend, no model downloads; no APK build attempted
(known other_tcp Gradle blocker, no circumvention).

## Verdicts

### 1. "Ontological & Cybernetic Metasystem" — ADAPTED

There is no autonomous self-optimizing organism. What is real:
the Rust daemon core (`libdaemon.so`, FFI ABI 2), the Flutter
UI, and the Kotlin foreground service, with local-first provider
routing (circuit breaker falling back to local Ollama). The
myth's "eliminates external telemetry bleed / third-party
middleware / subscription overhead" is REJECTED as written:
cloud provider clients (NVIDIA/OpenAI/Gemini/ElevenLabs/Deepgram)
still exist in the app as opt-in clients, the app still builds
on Flutter and Rust crates, and there is no subscription
infrastructure at all — so there is no subscription overhead to
"eliminate". The honest statement is: local paths exist and
cloud calls require the buyer's own keys; nothing is eliminated
by declaration.

### 2. "Autopoietic Epigenetics" — REJECTED as written, ADAPTED in part

"Modifying runtime execution trees from real-time feedback
loops WITHOUT human intervention" is REJECTED: it conflicts
with the locked human-approval rule, and no unsupervised
runtime-tree modification is built anywhere in this change.
The bounded honest equivalent already exists in Dart and is
NOT duplicated in Rust: `flutter_app/lib/core/danny_upgrades.dart`
(Danny's bounded self-upgrade: PAD ±0.15, talkativeness and
volatility ±0.10, self-note ≤280 chars, kill switch ON,
append-only accountability ledger in `danny_ledger.dart`,
persistence via SharedPreferences). If that persistence ever
moves to the daemon store, the `rga_store_put` / `rga_store_get`
FFI already exists for it — no new tuner was written, because
a second tuner would be a second source of truth.

### 3. "Recursive Bounded Spawning (N ≤ 3)" — BUILT

`rich_gang_ai_core/src/spawn_budget.rs`: a three-slot budget
for concurrent agent tasks. Acquire returns a slot id (0..2);
a fourth acquire returns the explicit error
`spawn_budget_exhausted` — the task is never silently queued,
never silently dropped, never run over the bound. Release of a
not-held or invalid slot is an explicit error, so capacity
cannot be inflated by a double release. It spawns no processes,
threads, or agents; it gates task concurrency. Tests:
3 unit tests (exhaustion, release-reacquire, double/invalid
release) + 1 FFI test. FFI: `rga_spawn_state` /
`rga_spawn_acquire` / `rga_spawn_release`; Dart bindings in
`native_bridge.dart` (`spawnState` / `spawnAcquire` /
`spawnRelease`).

### 4. "Autophagic Garbage Reclamation" — ADAPTED, parts REJECTED

REJECTED as written: there are no "necrotic thread execution
stacks" and no "raw byte primitive pool" in this daemon, and
this change invents neither. Time-based expiry is NOT built:
the store schema is `kv(key, value)` with no timestamp column,
so expiry cannot be proven from the schema — automatic
time-based purging is documented here as not built, not faked.
BUILT, from real store state, in
`rich_gang_ai_core/src/reclaim.rs`:
- `report` — entry count, persistence, journal mode, and the
  key list (rowid order), straight from SQLite.
- `delete_named` — deletes ONLY the keys the caller names,
  reporting per key whether it was deleted or already missing.
- `trim_to_cap` — enforces a caller-supplied cap by deleting
  oldest-first (rowid order) beyond it, reporting exactly which
  keys were removed and how many remain; a cap of zero is an
  explicit error, never a wipe. The cap is caller policy, never
  a default invented here.
Tests: 5 unit tests + 1 FFI test. FFI: `rga_reclaim_report` /
`rga_reclaim_delete` (JSON array of keys) / `rga_reclaim_trim`;
Dart bindings (`reclaimReport` / `reclaimDelete` /
`reclaimTrim`). The memory-mapped ring's capacity accounting
needed no new code: `rga_ring_state` already reports real
capacity, head, tail, pending bytes and pending messages from
`ring_ipc.rs` (CRC v2).

### 5. "Deterministic Multi-Agent Arbitration Pipeline" — ADAPTED

BUILT, the ingestion stage only:
`rich_gang_ai_core/src/intent_queue.rs` — a fixed-capacity
FIFO of intent strings. Enqueue past capacity returns the
explicit error `intent_queue_full`; the refused intent is
never stored and never silently dropped. Dequeue order always
equals enqueue order (asserted by test). Capacity is caller
policy from the daemon config key `intent_queue_capacity`
(default 64 — a default, documented as such, never a measured
figure); an explicit zero is a daemon-start error. Tests:
4 unit tests + 1 FFI test. FFI: `rga_intent_state` /
`rga_intent_enqueue` / `rga_intent_dequeue`; Dart bindings
(`intentState` / `intentEnqueue` / `intentDequeue`).
Arbitration itself is NOT a new pipeline: it already exists
as the Roundtable's sequential context passing plus Danny's
draft → critique → revise chain
(`flutter_app/lib/core/roundtable.dart`,
`danny_chain.dart`). The screenshots cut off the pipeline's
full stage list, so no further stages are claimed or built —
ungrounded stages stay unbuilt.

### 6. "High-Performance Cryptographic & Execution Core" / "Nodal Mesh" — ADAPTED, parts REJECTED

The real interconnection graph already exists and is the only
thing this claim maps to: `rich_gang_ai_core/src/topology.rs`
(petgraph causal topology, config-driven, deterministic
reachability via `rga_topology_state` /
`rga_topology_reaches`). No new graph was built and no
"cryptographic core" was built — no new cryptography is
claimed anywhere in this change. The screenshot's persona list
is NOT roster truth: it contains a pre-scrub name that was
dropped on 2026-10-22 and replaced by Crazy Kelly ("The Neon
Wildcard"). Roster truth comes from characters.json only, and
the dropped name appears nowhere in the code or docs added
here. The screenshot's "memory-mapped SQLite FTS5
state-stores" phrasing is REJECTED as written (see §7):
what is memory-mapped is the IPC ring (`ring_ipc.rs`,
memmap2, CRC v2), and what stores state is the rusqlite kv
store — they are two different components, and this document
does not merge them.

### 7. "Memory-mapped SQLite FTS5 state-stores" — REJECTED as written

Locked decision (2026-10-30): Rust rusqlite is the single
conversation store; Android Room FTS5 stays parked and
unwired. No Room code was touched, no FTS5 index was built,
and no store was renamed to imply one. The real store is
`rich_gang_ai_core/src/store.rs` (single-table SQLite kv,
WAL when file-backed, in-memory otherwise, state surface
says which).

## What was built (summary)

- New Rust modules: `spawn_budget.rs`, `intent_queue.rs`,
  `reclaim.rs` — all additive, no existing behavior changed.
- Daemon wiring: `spawn` and `intents` fields on `Daemon`
  (mutex-guarded), `intent_queue_capacity` config key.
- New FFI exports (all additive, ABI stays 2): 3 spawn +
  3 intent + 3 reclaim = 9 exports.
- Dart bindings: 9 wrapper methods in `native_bridge.dart`.
- Dart test: `flutter_app/test/execution_matrix_test.dart`
  (lookup + module source locks).
- Rust tests added: 12 unit + 3 FFI = 15; host cargo suite
  moved 78 → 93 passed (see gate output below).

## Honestly unwired / next

- Dart-side wiring of the intent queue into the Roundtable UI
  (enqueue on user intent, dequeue into arbitration) is NOT
  done: the queue exists at the daemon layer with bindings,
  but no UI calls it yet. That wiring is the next slice, and
  it must not invent arbitration stages.
- No UI was redesigned and no screen was changed.
- Danny's bounded upgrades stay in Dart; moving their
  persistence to the rusqlite store is possible via the
  existing store FFI but is not done here.
- Time-based store expiry is not built (schema has no
  timestamps) and must not be claimed.
- No APK build attempted (other_tcp blocker); nothing here
  is device-verified.
