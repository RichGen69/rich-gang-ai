# SPIKE V5-005 — memmap2 SPSC ring buffer (v5 Tier 5 design proof)

Date: 2026-10-23. Authorised by Richard: "Resume" (advancing the Rich Gang
AI app after spike 004 closed the crate queue; the spike 004 record required
a design before any memmap2 integration).
Design: `docs/DESIGN_MEMMAP2_RING_2026-10-23.md`
Location: `spikes/v5_005_memmap_ring/` — isolated crate, NOT a dependency
of `rich_gang_ai_core`.

## What was built
The design doc's protocol, exactly: 64-byte header (magic "RGRB0001",
capacity, producer-owned monotonic head, consumer-owned monotonic tail),
length-prefixed records that never straddle the data-area end (wrap marker
0xFFFF_FFFF or <4-byte pure padding, both counted in the counters),
head published last after a SeqCst fence, counters via volatile access.
Producer `send` on a full ring returns `ring_full` and writes nothing;
consumer `recv` on empty returns Ok(None) — a real empty state.
Wrong-role calls, bad magic, capacity mismatch, non-power-of-two or
<64 capacity, empty or >capacity/2 messages are all explicit errors.

## Results — real, run in this session (Rust 1.99.1)
- Host: `cargo test` — **6 passed, 0 failed**
  - in_order_across_two_mappings, consumer_opened_after_sends_sees_pending,
    wraparound_preserves_order (40 messages through a 64-byte ring),
    full_is_explicit_error_and_nothing_is_overwritten (5×12-byte records
    fill 64 bytes; 6th rejected; first message intact; send works after recv),
    bad_capacity_and_size_are_rejected, wrong_role_and_bad_magic_are_errors
- Android target: `cargo check` + `cargo build` for aarch64-linux-android —
  **pass** (NDK r27, API 24 clang); `libv5_005_memmap_ring_spike.rlib`
  produced; an extracted object verifies with `file` as
  **ELF 64-bit LSB relocatable, ARM aarch64**.
- memmap2 resolved to **0.9.12** (Cargo.lock).

## Verdict
**PASS — spike level only.** The SPSC ring protocol from the design doc
works over two coherent mappings of one file on host and cross-compiles
cleanly for the Android target.

## What this does NOT prove
- Not cross-process and not Dart-side: both mappings lived in one host
  process; Linux page-cache coherence within one OS is all that is proven.
  Nothing ran on the A16 (no APK exists — other_tcp blocker unchanged).
- No per-record CRC: crash scope is the design doc's (unpublished record
  invisible; crash during head publication unhandled) — production use
  needs the CRC/commit hardening named in the design.
- No latency/throughput measurement; "zero-copy" describes the data path
  shape, not a measured performance claim.
- Not integrated: no core dependency, no FFI surface, no file lifecycle.
  Integration is a separate Richard go-ahead, now unblocked design-wise.
