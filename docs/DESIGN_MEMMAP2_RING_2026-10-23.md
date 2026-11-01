# Design — memmap2 SPSC ring buffer (pre-integration)
Date: 2026-10-23. Status: DESIGN + SPIKE (spikes/v5_005_memmap_ring/).
Not integrated into rich_gang_ai_core. This is the design the spike 004
record required before any memmap2 integration decision.

> **PROTOCOL v2 UPDATE (2026-10-23, same day — supersedes the v1
> protocol described below where they differ).** The ring was
> integrated into rich_gang_ai_core at Richard's go-ahead
> (docs/INTEGRATION_V5_MEMMAP_RING_2026-10-23.md) and then hardened
> with per-record CRC-32. Changes from v1:
> - Header magic is now **"RGRB0002"**. v1 files ("RGRB0001") are
>   REJECTED by the consumer with an explicit `ring_bad_magic`
>   error — never silently misread. Migration stance: rings are
>   transient IPC files, truncated/recreated at every daemon start,
>   so there is NO data migration; an old file is simply refused.
> - Record layout is now **[u32 length][payload][u32 CRC-32]** —
>   CRC-32/IEEE (reflected, poly 0xEDB88320), implemented in-module
>   in `ring_ipc.rs` (table-driven, no new dependency), computed
>   over the 4 length bytes followed by the payload, so a torn
>   length field is detected as well as a torn payload. Record
>   overhead is 8 bytes (was 4). The producer writes length,
>   payload and CRC fully BEFORE publishing head — the CRC is part
>   of the record under the same head-published-last discipline.
> - Consumer validation, before any bytes are delivered: length
>   must be non-zero and <= capacity/2; the record must not
>   straddle the data-area end (the producer wraps instead); the
>   record must not extend past the published head (torn/partial);
>   and the stored CRC must match the recomputed CRC. ANY failure
>   returns an explicit **`ring_corrupt: offset=<logical tail>`**
>   error (surfaced verbatim as the FFI `error` value). Corrupt
>   bytes are never delivered, never silently skipped, and the
>   tail does NOT advance — every later recv reports the same
>   corruption until the ring file is recreated. The state walk
>   (`pending_counts`) applies the same validation and stops
>   counting messages at the first corrupt record.
> - Crash scope, narrowed precisely: the CRC PROVES a delivered
>   record's bytes are exactly the bytes the producer checksummed
>   — a torn record published by a crash during/after head
>   publication is now DETECTED instead of delivered as garbage.
>   The CRC does NOT prove anything about records whose head was
>   never published (still invisible, as in v1), does not make
>   head publication itself atomic, and is not a defence against
>   a writer who recomputes CRCs (integrity check, not a MAC).
>   A head-commit record remains unbuilt; what changed is that
>   the failure mode it guarded against is now an explicit error,
>   not silent bad data.

## Purpose in the app (proposed, not shipped)
A single-producer / single-consumer (SPSC) byte-message channel backed
by one memory-mapped file, candidate for high-frequency small messages
(e.g. daemon <-> a second native reader). It is NOT a Dart channel yet:
no Dart/FFI reader exists in this design's scope.

## Layout
File = 64-byte header + data area (capacity bytes, power of two, >= 64).
Header (little-endian u64 fields at fixed offsets):
- 0..8   magic "RGRB0001" — consumer refuses a file without it
  (v2: "RGRB0002", see the update block above)
- 8..16  capacity of the data area
- 16..24 head: total bytes ever written (monotonic, producer-owned)
- 24..32 tail: total bytes ever consumed (monotonic, consumer-owned)
Position of a counter = counter % capacity. Occupancy = head - tail.

## Protocol (v1, as spiked — v2 deltas in the update block above)
- Records are length-prefixed: u32 payload length, then payload.
  A record never straddles the end of the data area: if it does not fit
  in the tail remainder, the producer writes a wrap marker
  (length = 0xFFFF_FFFF) in the remainder (or, if fewer than 4 bytes
  remain, no marker — the consumer derives the wrap from position)
  and writes the record at offset 0. Padding counts toward head/tail.
- Producer: computes record size, checks occupancy — if the record
  would exceed capacity it returns `ring_full` and writes NOTHING
  (no overwrite, no drop-oldest: backpressure is the caller's problem,
  stated, not hidden). Copies payload, issues a SeqCst fence, then
  publishes head. Head is published LAST, after the bytes.
- Consumer: reads head/tail; empty (head == tail) returns an explicit
  empty result (Ok(None) — a real empty state, not fabricated data).
  Copies the record out, fences, then publishes tail.
- Ownership: head is written ONLY by the producer, tail ONLY by the
  consumer — no field has two writers, so no lock is needed. Counters
  are read/written with volatile accesses + SeqCst fences (spike-level
  discipline for same-OS shared page cache mappings).

## Crash rules (stated limits — v1 text; v2 narrowing above)
- Crash mid-record: the record is simply invisible IF head was not yet
  published (payload bytes may be torn in the file; they are never
  exposed because head never passed them). No checksum in the spike:
  a crash exactly during head publication is out of scope and must be
  solved (e.g. per-record CRC + head commit record) before any
  production/integration use. This design does NOT claim crash safety
  beyond the unpublished-record case.
- Reopen: create() truncates (new cycle). open() validates magic and
  capacity and resumes counters as stored — spike-tested for the
  consumer-opens-after-producer case only.

## What would still be missing for integration
Dart-side or second-process reader, CRC/commit hardening, an FFI
surface design, lifecycle (who creates/deletes the file, Android
app-private storage path), and a decision on what traffic, if any,
actually needs this versus the existing slot-locked ring_buffer +
FFI calls. Integration remains a separate Richard go-ahead.
(Status note: integration was authorised and completed 2026-10-23,
and the CRC hardening named here was added the same day — the two
items above are DONE; the Dart-side/second-process reader, head-
commit record, and traffic decision remain open.)
