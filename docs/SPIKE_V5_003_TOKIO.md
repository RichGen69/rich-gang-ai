# SPIKE V5-003 — tokio (v5 Tier 1: Async Runtime Core)

Date: 2026-10-23. Authorised by Richard: "Start the v5 verification spikes, one crate at a time" (spike queue continued 2026-10-23: "keep the spike queue moving to 003 (tokio)").
Location: `spikes/v5_003_tokio/` — isolated crate, NOT a dependency of `rich_gang_ai_core`.

## Verified before coding
- Cargo.lock confirms: tokio **1.54.1** from crates.io — the current stable 1.x line at
  spike time. 8 packages locked total: tokio, tokio-macros, pin-project-lite, and the
  proc-macro support crates (proc-macro2, quote, syn, unicode-ident). All pure Rust.
- Features enabled: `rt`, `rt-multi-thread`, `time`, `sync`, plus `macros` (needed for
  `#[tokio::test]`). Deliberately NOT enabled: `net`, `fs`, `process`, `signal`, `full`.
  Consequence, stated honestly: tokio's I/O driver (mio) is **not in this dependency
  tree at all**, so this spike says nothing about tokio networking — the v5 UDP-mesh
  claim would need `net` exercised in a separate proof.
- APIs used, all real in tokio 1.54.1: `runtime::Builder::new_multi_thread /
  new_current_thread`, `Runtime::block_on`, `tokio::spawn`, `JoinHandle` await,
  `sync::oneshot`, `sync::mpsc`, `sync::Mutex`, `time::interval`, `time::timeout`.

## What was built in the spike
Four small async helpers whose only job is to produce checkable outputs:
- `squares_via_oneshot(n)` — spawns n tasks; each computes i*i and returns it through
  its own oneshot channel; a dropped sender is an explicit `Err`, never a placeholder.
- `fan_in_via_mpsc(workers, per_worker)` — workers send sequence values over one mpsc
  channel; returns everything received (sorted for comparison).
- `shared_counter(tasks, per_task)` — tasks increment one tokio `Mutex` counter;
  any lost update fails the final assertion.
- `count_interval_ticks(period, ticks)` — counts real `interval.tick().await`
  resolutions; the count is produced by the awaited loop, not a wall-clock estimate.
- `never()` — a pending-forever future used to prove `timeout` really fires.

## Results — real, reproduced in this session
- Host: `cargo test` — **8 passed, 0 failed**
  - multi_thread_runtime_completes_spawned_tasks (Builder multi-thread, 2 workers:
    oneshot results exactly [0, 1, 4, 9, 16, 25, 36, 49])
  - current_thread_runtime_completes_spawned_tasks (Builder current-thread:
    oneshot results exactly [0, 1, 4, 9, 16])
  - mpsc_fan_in_delivers_every_value (4 workers × 3 values = all 12, none lost/duplicated)
  - shared_counter_has_no_lost_updates (8 tasks × 250 increments = exactly 2000)
  - timeout_fires_on_pending_future (50 ms timeout on a pending future = explicit Err)
  - timeout_passes_through_a_fast_value (fast future returns 42 inside a 5 s timeout)
  - interval_ticks_the_counted_number_of_times (3 ticks counted, then 1 tick counted)
  - spawned_task_result_comes_back_via_join_handle (sum 1..=100 = exactly 5050)
- Android target: `cargo check --target aarch64-linux-android` — **pass**
  (NDK r27, API 24 clang; same CARGO_TARGET/CC/CXX/AR env pattern as build_android.sh
  and spike 002)
- Android target: `cargo build --target aarch64-linux-android` — **pass**;
  produced `libv5_003_tokio_spike.rlib` (6.4 MB debug) and `libtokio-*.rlib`
  (16 MB debug); object files extracted from the spike rlib verify with `file` as
  **ELF 64-bit LSB relocatable, ARM aarch64**. Debug sizes only — no release/size claim made.

## Verdict
**PASS — spike level only.**
tokio 1.54.1 (rt + rt-multi-thread + time + sync) is viable as the v5 async runtime
candidate: both runtime flavours genuinely execute spawned tasks to completion with
real channel/join results on host, timers and timeout behave as asserted, and the
whole tree cross-compiles cleanly for aarch64-linux-android under the project's
NDK r27/API 24 toolchain.

## What this does NOT prove
- Not integrated into `rich_gang_ai_core`, not exposed over FFI, not in `libdaemon.so`
- Not device-verified (nothing ran on the A16 — no APK exists yet, other_tcp blocker
  unchanged). Android is proven at compile level only, same as spikes 001/002;
  spike 002's hope that this spike would prove a runtime "runs on the target" is
  NOT met — running on the target requires a device, and no test here ran on one.
- Runtime execution semantics (task completion, timers, channels) are proven on
  host (x86_64 Linux) only.
- No networking proof: `net`/mio was not enabled or exercised; the v5 UDP multicast
  mesh (224.0.0.123:8888) claim is untouched by this spike.
- No JNI story: nothing here proves how a tokio runtime should be started, stopped,
  or thread-attached from the Android/JNI side of the daemon — that is an
  integration-design question, not answered by a compile pass.
- No scheduling proof: tokio-cron-scheduler (v5 Tier 8) is a separate crate, not spiked.
- No performance measurement, no latency claim, no thread-count tuning.

## Next spike in queue
004 — memmap2 (v5 Tier 5: zero-copy IPC ring buffers). This follows the spike
sequence in docs/GAP_AUDIT_V5_2026-10-22.md ("Spike, one at a time … tokio,
rusqlite (bundled), petgraph (pure Rust, likely easiest), memmap2") — petgraph,
rusqlite, and tokio are now done, leaving memmap2 as the last of that sequence.
After it, the same audit names the hard spikes as separate decisions, none of
them promised: llama-cpp-rs + Vulkan on Adreno, candle, and LanceDB — each a
large dependency that may not cross-compile cleanly.
