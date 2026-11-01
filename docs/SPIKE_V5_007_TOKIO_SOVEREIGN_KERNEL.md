# SPIKE V5-007 — corrected Tokio sovereign-kernel lifecycle

Date: 2026-10-30. Location: `spikes/v5_007_tokio_sovereign_kernel/` — isolated crate, NOT a dependency of `rich_gang_ai_core`.

Note on naming: `v5_006` was already taken by the LanceDB spike, so this
is `v5_007`. It implements the lifecycle proof proposed as spike 006 in
`docs/DESIGN_TOKIO_INTEGRATION_2026-10-23.md`, applied to Richard's
pasted `MasterSovereignKernel` enum.

## What was built

- `SovereignCommand` with the pasted variants: `ExecuteAgentInference`,
  `SyncLocalMemory`, `ClusterTelemetryBroadcast`, `SystemShutdown`.
- One named OS thread (`sovereign-kernel`) running a single
  current-thread Tokio runtime (tokio 1.54.1, features `rt`, `time`,
  `sync`, `macros`; `net`/`fs`/`rt-multi-thread` deliberately OFF).
- `SovereignKernel::shutdown()` sends `SystemShutdown`, then joins the
  thread and returns a `KernelOutcome` with exact counts. That return
  IS the join proof: it cannot be produced while the thread is alive.
- `close_channel()` drops the handle's sender and joins, proving the
  channel-close exit path with `channel_closed: true`.
- A parked task (pending future) is aborted at shutdown and asserted
  never to complete.

## Honest corrections to the paste (no mock behaviour)

- Inference: NO provider exists here. The reply is
  `ERROR no_inference_provider: agent_id=... prompt_chars=... no model
  executed, no response generated`. No MediaPipe, GPU, or generated
  response is claimed anywhere.
- Memory sync: in-memory receipt only (row id + payload length).
  Nothing is written to disk; no SQLite/FTS5 claim is made.
- Telemetry: in-memory receipt only. Nothing is sent anywhere;
  no GKE/TPU/cluster code exists in this crate.
- No latency claim, no cost claim. Unused imports from the paste
  (`sleep`, `Duration`, `Arc` as pasted) are removed; the runtime
  actually starts instead of only being printed about.

## Results — real, reproduced in this session

- Host: `cargo test` — **4 passed, 0 failed**
  - kernel_routes_all_command_kinds_and_shuts_down_cleanly
    (1 inference error receipt, 1 memory receipt, 1 telemetry receipt,
    heartbeat >= 1, shutdown_clean, parked task not completed)
  - parked_task_is_cancelled_on_shutdown
  - channel_close_ends_thread_via_public_api
  - run_kernel_ends_on_channel_close (loop-level close path)
- Demo: `cargo run --bin sovereign_kernel_demo` — inference receipt
  printed as the no-provider error; shutdown outcome
  `shutdown_clean: true, parked_task_completed: false`.
  (Heartbeat was 0 in the demo run because it shuts down immediately;
  the test that waits for ticks is the heartbeat proof, not the demo.)
- Android target: `cargo build --target aarch64-linux-android`
  (NDK r27, API 24 clang, same env pattern as `build_android.sh`) —
  **pass**; extracted objects verify as ELF 64-bit LSB relocatable,
  ARM aarch64. Debug sizes only; no release/size claim made.
- Not run: `cargo fmt --check` / `cargo clippy` — those components
  are not installed for this toolchain in this VM, so no fmt/clippy
  claim is made.

## What this does NOT prove

- Not integrated into `rich_gang_ai_core`, not exposed over FFI/JNI,
  not in `libdaemon.so` — the verified core was not touched.
- Not device-verified: nothing ran on a phone. Android is proven at
  compile level only.
- No inference provider, no persistence, no telemetry transport, no
  networking, no JNI thread attachment, no scheduling/latency claim.
- `join()` without a prior shutdown command (via a sender clone) or
  `close_channel()` blocks until the loop ends; that is documented
  in the API, not hidden.
