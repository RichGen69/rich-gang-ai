# SPIKE V5-004 — memmap2 (v5 Tier 5: Zero-Copy IPC Streaming)

Date: 2026-10-23. Authorised by Richard: "Fix bugs and contine" [continue] — continuation of the v5 spike programme (001 petgraph → integrated, 002 rusqlite → integrated, 003 tokio → spike PASS per parallel session).
Location: `spikes/v5_004_memmap2/` — isolated crate, NOT a dependency of `rich_gang_ai_core`.

## Verified before coding
- docs.rs source for memmap2 shows the real API: `MmapOptions::new().map_mut(&file)` / `.map(&file)` (both `unsafe`, with the crate's documented safety terms), `MmapMut`/`Mmap`, `flush()`.
- Cargo.lock confirms the exact build used: memmap2 **0.9.12** from crates.io (the "0.9" requirement resolved to the current patch).

## What was built in the spike
`MmapBuffer` over a file it creates and exclusively owns: create+set_len+map_mut, bounds-checked `write_at`/`read_at` (out-of-bounds = explicit error, never a clipped write), `flush()` (msync), plus `read_via_fresh_map` — a second, read-only mapping of the same file as the "other side" view. Zero length is rejected explicitly. The unsafe map calls carry the module-doc safety contract (exclusive ownership, no external truncation/writes while mapped, file outlives mapping; spike maps only its own temp files).

## Results — real, reproduced in this session
- Host: `cargo test` — **5 passed, 0 failed**
  - write_then_fresh_map_sees_the_same_bytes (writer's bytes visible through a separate mapping after flush+drop)
  - remap_after_drop_starts_a_clean_cycle, out_of_bounds_is_an_explicit_error, zero_length_is_rejected, offsets_are_exact_not_rounded
- Android target: `cargo check --target aarch64-linux-android` — **pass** (NDK r27, API 24 clang)
- Android target: `cargo build --target aarch64-linux-android` — **pass**; `libmemmap2-*.rlib` (530K debug) produced for the target

## Verdict
**PASS — spike level only.**
memmap2 0.9.12 does real memory-mapped file I/O on host and cross-compiles cleanly for aarch64-linux-android.

## What this does NOT prove
- A memory map is not a "zero-copy FFI ring buffer": there is no producer/consumer protocol, no cross-process or Dart-side reader, no ordering/cache discipline, and no latency measurement in this spike. The existing core ring_buffer remains slot-locked and honestly labelled not-zero-copy.
- Not integrated into `rich_gang_ai_core`, not in `libdaemon.so`, not device-verified (nothing ran on the A16).
- Integration is a separate decision requiring Richard's go-ahead, and — unlike petgraph/rusqlite — it should start with a design (who writes, who reads, how offsets/lengths are shared, what happens on crash mid-write), not just a dependency add.
