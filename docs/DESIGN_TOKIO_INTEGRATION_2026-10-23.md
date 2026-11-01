# Design — Tokio integration for rich_gang_ai_core (DESIGN ONLY)

Date: 2026-10-23. Status: **DESIGN ONLY — tokio is NOT integrated by
this document, and this document authorises nothing.** Written at
Richard's directive ("Fixed problems add solutions") to close the
open design question left by spike V5-003
(`docs/SPIKE_V5_003_TOKIO.md`: tokio 1.54.1, features rt /
rt-multi-thread / time / sync / macros, host 8/8, Android aarch64
check+build pass — compile-and-host level only, `net` feature OFF,
so the spike proved the runtime core and said nothing about tokio
networking).

## The question this design answers

The daemon's execution model today is fully synchronous:

- Every FFI export (`rga_*`) and every JNI entry
  (`nativeBoot/nativeTick/nativeQuery/nativeStop` from the Kotlin
  `DreamCycleService`) does its work on the CALLER's thread and
  returns. The core spawns no threads of its own (verified: no
  `std::thread::spawn` outside tests in `rich_gang_ai_core/src/`).
- The dream-cycle cadence is owned by Kotlin (foreground service +
  WorkManager), which calls `nativeTick` — the scheduler is
  Android's, not Rust's.
- The core does no networking at all (verified: no sockets, no
  HTTP client in the crate; cloud providers are called from Dart).

So an async runtime has no existing caller. The integration
question is therefore not "how do we plug tokio in" but "who would
own it, what would it run, and how does it die cleanly" — answered
below, in that order of importance.

## Runtime ownership

- **Owner: the `Daemon` struct** (lib.rs), the same object that
  owns the store, the topology graph, and the ring. One runtime per
  daemon instance, stored as a field `runtime: Option<tokio::runtime::Runtime>`
  beside them. No globals, no lazy-static runtime shared across
  daemon instances — the handle registry already allows the FFI
  layer to hold a daemon by handle, and a shared global runtime
  would outlive any one daemon's stop.
- **Created in `Daemon::new`**, i.e. inside `rga_daemon_start`
  (and the JNI `nativeBoot` path, which constructs the same
  `Daemon`). If runtime construction fails, daemon start fails
  with an explicit error — the established posture for the store
  and the ring (an unopenable `store_path` / `ring_path` already
  fails start; no silent degraded mode).
- **Destroyed in `Daemon::drop`**, which is what `rga_daemon_stop`
  triggers when the handle is unregistered. Destruction is the
  shutdown protocol in the "Failure/shutdown semantics" section —
  never a bare drop of a runtime with live tasks.

## Thread model

- **`new_current_thread` runtime, one dedicated OS thread.**
  Rationale:
  - The daemon is an in-process library inside a Flutter app on a
    phone. A multi-thread runtime parks a worker pool (default =
    one worker per core) for work that, today, does not exist; on
    Android those idle threads still cost stacks and scheduler
    presence, and they complicate the JNI picture below.
  - A current-thread runtime driven by one spawned
    `std::thread` ("the daemon async thread") gives a single,
    nameable owner for all async work: tasks are spawned onto it,
    it runs `block_on` on a root future that selects over the
    daemon's async work and a shutdown signal, and joining that
    thread is the shutdown proof.
  - If a future consumer genuinely needs parallelism (the UDP mesh
    is the only named candidate, and it is I/O-bound, not CPU-bound),
    moving to `new_multi_thread` with `worker_threads(2)` is a
    config change inside `Daemon::new`, not a redesign. The design
    deliberately does NOT start there.
- **Enable only the drivers that are used.** Runtime built with
  `enable_time()`; `enable_io()` only when a consumer with real I/O
  exists (that is also the moment the `net` feature and mio enter
  the dependency tree, which spike 003 explicitly did not test).
  An idle I/O driver is not free on Android and buys nothing today.

## JNI thread-attachment implications

- Rust-spawned threads are NOT attached to the JVM. Any future task
  that needs to call into Kotlin/Java (e.g. to raise a callback
  into `DreamCycleService`) would need an explicit
  `JavaVM::attach_current_thread` (via the `jni` crate) for the
  duration of the call, with the daemon's `JavaVM` pointer captured
  at `nativeBoot`. **The chosen thread model has exactly one
  Rust-owned thread, so there is exactly one thread to reason
  about** — a multi-thread runtime would make any worker a
  potential JNI caller, each needing attachment, and tokio may
  move tasks between workers.
- Rule for the design: **async tasks never call JNI directly.**
  If a future consumer needs to notify Kotlin, it sends through a
  channel to a dedicated bridge point on the async thread, which
  is the one place attachment happens. No such consumer exists
  today; this rule costs nothing now and prevents the classic
  crash (calling JNI from a detached thread) later.
- The synchronous FFI/JNI surface is unchanged: `rga_*` exports
  keep doing their current work on the caller's (already attached)
  thread. Async results, if ever needed by Dart, would be polled
  through a new explicit FFI surface — none is designed here,
  because no consumer needs one yet.

## What the runtime would actually be FOR

Honest answer: **nothing in the current codebase needs it today.**

- All FFI calls are request/response and complete synchronously.
- The dream-cycle timer already exists and is Kotlin's.
- The watchdog is heartbeat/stale CHECKS evaluated on tick, not a
  timer task.
- Cloud providers are called from Dart over Dart's own async —
  moving them into Rust is a different project, not a tokio need.

Named candidate future consumers (real, previously recorded — not
invented for this document):

1. **The v5 Tier-6 UDP multicast mesh** (224.0.0.123:8888, per the
   v5 master prompt as pasted; GAP_AUDIT_V5 records it as NOT
   built — a Crew Link flag exists, default off, paired-only, with
   NO transport). A multicast listener is exactly a long-lived
   async I/O task, and this is the one consumer that would justify
   the runtime, the `net` feature, and the I/O driver. It is also
   a separate product decision (mesh protocol, pairing, security)
   that has not been made.
2. **A Rust-side periodic consolidator** — running dream
   consolidation without waiting for a Kotlin tick. Rejected as a
   justification on its own: it would duplicate a cadence Android
   already owns, and two schedulers for one cycle is a bug farm.

## Failure / shutdown semantics

- `rga_daemon_stop` (and `nativeStop`) must guarantee: **no task
  outlives the daemon.** Concretely:
  1. Stop closes a shutdown signal (a `watch`/`Notify` held by the
     `Daemon`) that the root future selects on;
  2. the async thread's `block_on` returns, and dropping the
     runtime then cancels remaining tasks — tasks are required to
     be cancellation-safe by construction (no task holds a lock
     or a half-written record across an `.await`; the ring and
     store are synchronous mutex-guarded calls that never span
     awaits);
  3. stop **joins the async thread** before returning. Joining is
     the observable proof of shutdown; a stop that returns while
     the thread still runs is a failed stop and must be reported
     as such, never silently detached. (Detached `Runtime` drop
     semantics — background shutdown — are explicitly not used.)
- A panic inside a task surfaces as a `JoinError` at the await
  point on the async thread, is logged through the core's existing
  `logging` path, and does not unwind across the FFI boundary
  (the existing FFI layer already wraps calls in `catch_unwind`).
- Double-stop stays safe: stop is already documented idempotent
  at the FFI layer; with no runtime after the first stop, the
  second is the same no-op.

## Spike 006 proposal (to prove this lifecycle before any integration)

Isolated crate `spikes/v5_006_tokio_lifecycle/`, depending on the
core only if needed (prefer standalone, mirroring spike 003):

1. Build a `current_thread` runtime on a spawned named thread,
   root future selecting over (a) a `time::interval` heartbeat
   counter and (b) a shutdown `Notify`; prove on host: N ticks
   counted, shutdown signal -> root future returns -> thread
   joined, all inside a test with a hard timeout (a hang fails
   the test, never passes silently).
2. Prove cancellation: a spawned task parked on a never-ready
   future is cancelled by runtime drop after shutdown, and the
   test asserts the thread still joined (no detached task).
3. Cross-compile + build for aarch64-linux-android (NDK r27,
   API 24, the project's established env pattern) and verify the
   produced objects are ELF ARM aarch64 — compile-level evidence,
   labelled as such.
4. NOT in spike 006: the `net` feature / UDP sockets (that is a
   spike 007, gated on the mesh decision), JNI attachment (no JVM
   exists in the spike environment; attachment can only be proven
   on-device, which remains blocked on the APK build permission).

Pass bar: host tests green with the shutdown/join assertions,
Android build green, and a spike record written in the
established shape including "what this does NOT prove"
(device run, JNI attachment, networking).

## Recommendation and the decision Richard needs to make

**Recommendation: do not integrate tokio now.** There is no
consumer; integrating a runtime with no tasks would add threads,
shutdown risk, and binary size in exchange for nothing the app
can use — the same reasoning that kept the ring disabled until it
had a design and a purpose. Run spike 006 instead: it is small,
it proves the one genuinely uncertain thing (clean lifecycle
under the daemon's start/stop), and it leaves integration as a
one-step follow-up the moment a consumer is approved.

**Decision needed from Richard (one of):**
- (a) **Approve spike 006** (lifecycle proof, no integration), or
- (b) **Approve the UDP mesh as a real feature** — which makes
  tokio's integration a by-product of that build and reorders
  everything above it, or
- (c) **Park tokio indefinitely** — spike 003's PASS stands as
  the compile-level evidence and no further time is spent until
  a consumer exists.
