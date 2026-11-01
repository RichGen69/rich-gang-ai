# Audit and delta — memmap2 SPSC ring design (v5 Tier 5)

Date: 2026-10-23.
Status: **critique-and-delta only. No source was changed, no dependency was
added, and nothing in this document makes the ring integrated or
device-verified.**

This audit does **not** replace or duplicate the parallel design. The baseline
under review is:

- `docs/DESIGN_MEMMAP2_RING_2026-10-23.md` — cited below as **[DESIGN]**.
- `docs/SPIKE_V5_005_MEMMAP_RING.md` — cited as **[SPIKE]**.
- `spikes/v5_005_memmap_ring/src/lib.rs` — cited as **[SPIKE-CODE]** by type or
  function name.
- `rich_gang_ai_core/src/ring_buffer.rs` — cited as **[CURRENT-RING]**.
- `tools/release_gate.sh` — cited as **[GATE]**.

## Executive verdict

**Agree with the baseline as a spike design; disagree that it is ready to be
treated as an integration design.**

The baseline is unusually honest about its limits: it is SPSC, bounded, does
not overwrite on full, returns a real empty state, and expressly withholds a
crash-safety claim beyond an unpublished record ([DESIGN] §“Purpose in the
app”, §“Protocol”, and §“Crash rules (stated limits)”).

The blockers are not the basic byte-ring idea. They are:

1. volatile access plus fences is presented as the synchronization discipline,
   but that does not establish a sound Rust or Rust↔Kotlin shared-memory
   protocol ([DESIGN] §“Protocol”; [SPIKE-CODE] `load_u64` / `store_u64`).
2. The consumer trusts a length field before validating it against the
   published byte range, so crafted or torn state can cause a panic instead
   of the required explicit corruption error ([SPIKE-CODE] `Ring::recv`).
3. There is no production lifecycle, Android path, ownership arbitration,
   Kotlin reader, FFI/JNI surface, security model, delivery/commit semantics,
   or release-gate step. The baseline itself lists several of these as missing
   ([DESIGN] §“What would still be missing for integration”), but an
   implementation plan cannot leave them as prose-level unknowns.

The corrected path below therefore keeps the proven spike as evidence for a
**bounded byte-ring format**, while changing the production target to a
**Rust-owned control plane with an optional, separately proven Kotlin
read-only payload reader**. Direct Kotlin writing of shared counters is a
no-go until its memory-ordering and Android runtime behaviour are proven.

---

# 1. Coverage audit against the brief

## 1.1 Covered — retain without rewriting

### SPSC shape and bounded semantics — covered

[DESIGN] §“Purpose in the app” chooses one producer and one consumer;
§“Protocol” defines monotonic byte counters, wrap markers or implicit wrap
padding, a full ring returning `ring_full`, and an empty ring returning
`Ok(None)`. [SPIKE] §“Results” reports tests for ordering across two
mappings, late consumer attach, wrap, full, invalid size/capacity, roles,
and bad magic.

**Audit position:** agree. These semantics match the current core ring's
refusal to overwrite and its explicit empty result ([CURRENT-RING] header
and `AtomicRingBuffer::try_push` / `try_pop`).

### Basic layout — covered at spike level

[DESIGN] §“Layout” specifies a 64-byte header, magic `RGRB0001`, data
capacity, producer-owned written-byte counter (`head`), and consumer-owned
consumed-byte counter (`tail`). [SPIKE-CODE] constants `HEADER`, `MAGIC`,
`OFF_CAP`, `OFF_HEAD`, and `OFF_TAIL` implement those offsets exactly.

**Audit position:** agree for the spike format. It is not sufficient as the
production header; see Finding F-04.

### Crash limitation disclosure — covered, and it is a blocker

[DESIGN] §“Crash rules (stated limits)” says an unpublished record is
invisible only if the written-byte counter was not published, and expressly
says a crash during publication is out of scope. [SPIKE] §“What this does
NOT prove” repeats that there is no per-record CRC.

**Audit position:** agree with the disclosure; disagree with any later
summary that shortens it to “crash-safe.” The disclosed limitation blocks
production use until §4 of this delta is implemented and tested.

### Non-integration status — covered

[DESIGN] header and §“What would still be missing for integration”, plus
[SPIKE] §“Verdict” and §“What this does NOT prove”, all preserve spike-level
status: one host process, no Dart reader, no second process, no A16 run, and
no measured latency or throughput.

**Audit position:** agree. No wording in an implementation report may call
this “integrated” until the gates in §7 pass.

## 1.2 Partially covered or missing

| Brief requirement | Audit result | Evidence |
|---|---|---|
| Concrete problem / traffic that needs mmap | **Missing** | [DESIGN] §“Purpose in the app” says only “candidate for high-frequency small messages (e.g. daemon <-> a second native reader)” and §“What would still be missing” leaves the traffic decision open. |
| Honest “zero-copy” naming by boundary | **Partial / misleading if shortened** | [SPIKE] §“What this does NOT prove” restricts “zero-copy” to “data path shape”; [SPIKE-CODE] `Ring::send` copies payload into the map and `Ring::recv` copies it out with `to_vec()`. |
| Sound atomics over mmap | **Missing / not proven** | [DESIGN] §“Protocol” names volatile accesses + SeqCst fences; [SPIKE-CODE] `load_u64` fences before the load and `store_u64` writes before its fence. No cross-language or formal shared-memory proof is supplied. |
| Android lifecycle and storage | **Missing** | [DESIGN] §“What would still be missing for integration” expressly lists lifecycle and app-private path as missing. |
| Production header, record sequence, integrity | **Missing** | [DESIGN] §“Layout” has no version field separate from the magic, state, generation, header CRC, record sequence, record CRC, or commit/trailer field. |
| Kotlin `MappedByteBuffer` reader | **Missing** | [DESIGN] §“What would still be missing for integration” lists a second-process reader as missing; [SPIKE] §“What this does NOT prove” says both mappings were in one host process. |
| FFI/JNI/Dart surface | **Missing** | [DESIGN] §“Purpose in the app” says no Dart/FFI reader is in scope; §“What would still be missing” lists an FFI surface as missing. |
| Security | **Missing** | Neither [DESIGN] nor [SPIKE] contains a security section; the only access control in [SPIKE-CODE] is a role enum and magic check. |
| Corruption behaviour beyond bad magic | **Missing and partly unsafe in code** | [SPIKE-CODE] `Ring::open_consumer` validates magic and capacity equality; `Ring::recv` then slices using an unchecked record length. See F-03. |
| Test plan beyond spike tests | **Missing** | [SPIKE] §“Results” lists six host tests, but no concurrent-thread, second-process, corruption-fuzz, lifecycle, Kotlin/Android, or artifact-gate plan. |
| Phases, go/no-go, blast radius | **Missing** | [DESIGN] §“What would still be missing for integration” is a list, not a phased plan with acceptance or rollback criteria. |
| Release-gate mandate | **Missing — explicit gap** | Neither [DESIGN] nor [SPIKE] mentions `tools/release_gate.sh`. [GATE] header says it must be run after any change to `rich_gang_ai_core/` or `native_bridge.dart`, before a build is called integrated, staged, or ready. |
| Alternatives analysis | **Partial** | [DESIGN] §“What would still be missing” asks what traffic needs this versus the current ring + FFI calls, but does not evaluate crossbeam or Android `SharedMemory`. |

---

# 2. Findings and required corrections

## F-01 — Blocker: there is still no justified production workload

**Evidence.** [DESIGN] §“Purpose in the app” proposes “high-frequency small
messages” only as a candidate. The existing core ring is not shown to be a
measured bottleneck; [CURRENT-RING] is a generic in-process type and the
baseline does not identify a current producer, consumer, payload type,
message rate, or maximum payload from production traffic.

**Why it matters.** A file-backed shared ring adds unsafe mapping, lifecycle,
corruption, and cross-runtime risks. Without a workload, there is no basis
for its capacity, flush policy, polling interval, or performance claim.

**Required delta.**

- Name exactly one first workload before implementation. The only plausible
  first candidate in the current architecture is Rust-daemon event/dream
  frames consumed by `DreamCycleService`, not general chat traffic.
- Record payload type, maximum size, expected burst, delivery requirement
  (at-most-once or at-least-once), and what happens on full.
- If no workload can be named and measured against the existing FFI/JNI call,
  the correct decision is **no-go**, regardless of spike success.

## F-02 — Blocker: volatile + fences does not prove the synchronization protocol

**Evidence.** [DESIGN] §“Protocol” says separate ownership means “no lock is
needed” and describes counters as “volatile accesses + SeqCst fences.”
[SPIKE-CODE] `load_u64` performs `fence(SeqCst)` **before**
`read_volatile`; `store_u64` performs `write_volatile` and then
`fence(SeqCst)`. [SPIKE-CODE] `Ring::send` and `Ring::recv` otherwise access
payload bytes through `MmapMut` slices.

**Audit disagreement.** Single-writer fields remove write/write contention;
they do not by themselves establish:

- an acquire edge from reading the published counter to reading payload;
- a release edge covering every payload and framing byte;
- atomicity as an interoperable Rust↔JVM/Android ABI;
- freedom from Rust aliasing/data-race problems when two `Ring` objects hold
  mutable mappings of the same pages; or
- that a JVM `MappedByteBuffer` read has the ordering semantics this protocol
  assumes.

Passing the six sequential host tests in [SPIKE] §“Results” is evidence the
byte protocol can work under those test conditions. It is not a soundness
proof. In particular, the tests in [SPIKE-CODE] `mod tests` call producer and
consumer sequentially; they do not run concurrent producer/consumer threads.

**Required delta.**

1. Treat the spike synchronization as **experimental**, not “lock-free” and
   not formally sound.
2. For the production design, Rust owns all header counters and ring state.
   A Rust-side mutex serializes ring-manager operations for a daemon handle;
   in-process Rust atomics may be authoritative, while map counters are
   published state, not independently writable Kotlin state.
3. Kotlin may map the file **read-only** and read a payload only after a JNI
   claim described in F-07. Kotlin must not write `head`, `tail`, or any
   successor field in v1.
4. A direct-reader spike must prove, on the physical A16 and target Android
   runtime, the exact Kotlin access mechanism, byte order, aligned `u64`
   behaviour, and repeated sequence/CRC validation under concurrent load.
   Desktop JVM success is not a substitute.
5. If that proof fails, use a Rust-mediated JNI/FFI copy API and stop calling
   the design a direct shared-memory reader.

## F-03 — Blocker: `recv` can panic on torn or crafted framing

**Evidence.** In [SPIKE-CODE] `Ring::recv`, the code reads `len` from the map
and immediately forms `self.map[at + 4..at + 4 + len as usize]`. It does not
first prove that `len` is within the producer-published range, the remaining
data area, the configured maximum, or the file length. `Ring::send` uses
`head - tail` without first proving `head >= tail`. `Ring::open_consumer`
checks magic and capacity equality, but does not check that capacity is a
power of two or at least 64, even though [DESIGN] §“Layout” requires both.

**Why it matters.** The design goal is explicit corruption errors and an
honest empty state, not a panic, out-of-range slice, recursive wrap loop, or
invented payload. A stale, torn, restored, or same-UID-forged file is exactly
where those checks matter.

**Required delta — validate before any slice or counter arithmetic:**

- file length equals the header's declared total length;
- data capacity is a power of two, within the production minimum/maximum;
- `read_total <= write_total` and `write_total - read_total <= capacity`;
- frame length is nonzero for data, no greater than the production maximum,
  and fully contained in the published, unwrapped range;
- wrap handling is an iterative loop with a small bounded number of steps,
  never unbounded recursion;
- every failure returns a named error such as
  `ring_corrupt_frame_length`, `ring_counter_divergence`, or
  `ring_header_geometry`; it never panics and never advances the read
  counter over suspect bytes.

## F-04 — Major: the 64-byte spike header and 4-byte record prefix are not a production format

**Evidence.** [DESIGN] §“Layout” has only magic, capacity, head, and tail.
Its §“Protocol” record is only a `u32` length plus payload. There is no
independent format-version field, state, generation, data-area offset, total
file size, maximum payload, header integrity value, per-record sequence,
record kind, CRC, or commit/trailer check. [SPIKE-CODE] `Ring::create` also
writes magic before it writes capacity and counters, with no `INITIALIZING`
or `READY` state for an observer to reject.

**Required delta — production format must be versioned separately from the
spike format.** Do not silently reinterpret `RGRB0001` files. A v2 candidate
must specify, at minimum:

### Header delta

Use one 4,096-byte header page for the production candidate:

| Offset | Field | Size |
|---:|---|---:|
| 0 | magic `RGRB0002` | 8 |
| 8 | format version = 2 | 4 |
| 12 | header size = 4,096 | 4 |
| 16 | total file size | 8 |
| 24 | data capacity | 8 |
| 32 | maximum payload | 4 |
| 36 | frame overhead | 4 |
| 40 | generation | 8 |
| 48 | CRC-32 of immutable bytes 0..48 | 4 |
| 52 | state: initializing / ready / closed / quarantined | 4 |
| 56 | flags | 4 |
| 60 | reserved, must be zero in v2 | 4 |
| 64 | producer block: total bytes written | 8 |
| 72 | producer block: next frame sequence | 8 |
| 80 | producer block: last flushed frame sequence | 8 |
| 88 | producer block: session nonce | 8 |
| 128 | consumer block: total bytes consumed | 8 |
| 136 | consumer block: next expected frame sequence | 8 |
| 144 | consumer block: claimed frame sequence, or `u64::MAX` | 8 |
| 152 | consumer block: claim generation | 8 |
| 256..4096 | reserved, must be zero in v2 | 3,840 |

Producer and consumer blocks start on separate 64-byte boundaries. This is
a layout discipline, not a performance claim.

### Record delta

Each data or wrap frame has:

- 24-byte prefix: frame sequence `u64`, payload length `u32`, payload CRC-32
  `u32`, kind `u16`, flags `u16`, reserved `u32` (zero in v2);
- payload;
- 8-byte trailer repeating the frame sequence.

Total frame overhead is therefore **32 bytes**. A wrap frame has kind
`WRAP`, length 0, and the sequence expected at that point. If fewer than 32
bytes remain, the remainder is unframed padding counted in the byte counters,
as in the spike protocol.

### Production-size example — candidate, not a traffic claim

- header: 4,096 bytes;
- data area: 262,144 bytes (256 KiB, power of two);
- total file: **266,240 bytes**;
- maximum payload: 16,384 bytes;
- maximum complete frame: 16,384 + 32 = **16,416 bytes**;
- at most 15 maximum-size frames fit by raw division
  (15 × 16,416 = 246,240; 16 × 16,416 = 262,656 > 262,144), before
  wrap/padding effects.

These numbers make the format implementable and testable. Phase 0 must
replace or confirm them from the named workload in F-01; they are not
evidence that 256 KiB is the right operational size.

## F-05 — Major: crash and reopen semantics need commit and delivery rules

**Evidence.** [DESIGN] §“Crash rules (stated limits)” discloses the missing
CRC/commit hardening and says reopening resumes stored counters, tested for
“consumer-opens-after-producer” only. [SPIKE-CODE] has only
`Ring::create` (which truncates) and `Ring::open_consumer`; there is no
producer reattach operation and no claim/commit operation.

**Required delta.**

- A data frame is deliverable only when its prefix sequence, trailer
  sequence, expected sequence, length, kind, reserved fields, and CRC all
  validate. CRC is an integrity check, not authentication.
- Consumption is two-phase:
  1. `claim` reserves the next valid frame and returns its generation,
     sequence, kind, and length;
  2. the consumer copies/processes it;
  3. `commit` advances the consumed counter;
  4. `abandon` releases the claim without advancing.
- Delivery is therefore **at-least-once across a claim without commit**:
  a crash after claim but before commit may redeliver the same sequence.
  Callers must deduplicate by `(generation, sequence)` if their effect is
  not idempotent.
- A crash after commit but before an external effect is the caller's
  at-most-once risk; the ring must state this instead of pretending exactly
  once delivery.
- On daemon start, do not silently resume a `READY` file from an older
  process as though its producer were live. V1 production behaviour is to
  validate it, report any complete unclaimed frames through state, then
  rotate to a new generation before accepting new writes — or explicitly
  design and test producer reattach as a separate phase.
- A file in `INITIALIZING`, a bad static CRC, an unknown version, or a
  geometry mismatch is quarantined and reported as an explicit error/empty
  state. No payload is reconstructed or guessed.

## F-06 — Major: visibility is not durability, and flush policy is absent

**Evidence.** Neither [DESIGN] nor [SPIKE-CODE] specifies `flush`,
`flush_async`, file `sync_all`, or directory sync. [SPIKE-CODE] `Ring`
contains no flush call.

**Required delta.**

- State separately:
  - **visibility:** whether another mapping on the same running OS can see
    bytes;
  - **durability:** whether bytes survive process crash, OS crash, or power
    loss. These are not the same claim.
- V1 is a volatile channel. It must not promise durable queueing; SQLite
  remains the durable store already integrated in the core.
- Do not flush every frame by default. If crash snapshots are wanted, use a
  documented batch policy (for example every 128 published frames or on
  orderly close), propagate flush errors, and benchmark it on device before
  enabling it.
- Creation/close may use file and parent-directory synchronization outside
  the map, but even a successful sync is reported as an operation result,
  not converted into an unmeasured durability guarantee.

## F-07 — Major: the Kotlin reader in the baseline is not realistic yet

**Evidence.** [DESIGN] §“Purpose in the app” expressly puts a Dart/FFI
reader out of scope, and §“What would still be missing” leaves the
second-process reader unresolved. In the current app, `DreamCycleService`
loads `libdaemon` and boots a Rust handle with `nativeBoot("{}")`
(`DreamCycleService.kt`, companion object and `onCreate`), while Dart boots
its own handle from bundled config (`main.dart`, daemon boot section). The
Android manifest declares the service without a separate `android:process`,
so this design must not casually describe the participants as independent
processes.

**Required delta.**

- Designate **one canonical Rust daemon handle** as ring owner/producer.
  The other boot path must either share that handle through an explicit
  ownership design or start with the ring disabled. Two independently owned
  rings at the same path are a no-go.
- Kotlin is the only plausible direct reader in v1. It should:
  - open the app-private file with `RandomAccessFile` / `FileChannel`;
  - map it `MapMode.READ_ONLY`;
  - set the buffer byte order explicitly to little-endian;
  - retain the channel and buffer for the reader's lifetime rather than
    relying on timely unmapping;
  - read only a frame reserved by the Rust claim operation;
  - copy the payload into an owned Kotlin `ByteArray` before processing;
  - call Rust to commit or abandon the claim.
- This is **copy-reduced**, not end-to-end zero-copy: [SPIKE-CODE]
  `Ring::send` copies into the map and any safe Kotlin processing normally
  copies out of the direct buffer.
- Phase 0 must verify on the A16: FileChannel mapping behaviour, buffer
  order, aligned 64-bit reads, behaviour when the file is rotated, and the
  exact Android API/runtime level. `VarHandle` or any atomic buffer view is
  an unverified option until that spike exists; it must not be written into
  the production protocol as an assumption.
- Dart gets **no direct memory map** in v1. Dart may call a state API and,
  if a mediated payload path is later justified, receive an owned copy via
  existing FFI patterns.

## F-08 — Major: lifecycle and single ownership are unspecified

**Evidence.** [DESIGN] §“What would still be missing for integration”
expressly leaves creation/deletion and Android path unresolved.
[SPIKE-CODE] `Ring::create` truncates the target path; `open_consumer`
takes no owner lock and places no limit on how many consumers can open the
file.

**Required delta.**

- Path: `Context.noBackupFilesDir/rga/mmap-ring/dream-events-rgrb-v2.bin`.
  Do not use external storage or `cacheDir` for the authoritative ring.
- Kotlin supplies the absolute app-private directory through daemon config;
  Rust must not guess an Android path. Current service boot passes `"{}"`,
  so passing a real path is an explicit implementation change.
- Creation uses a temporary file in the same directory, writes the header
  in `INITIALIZING`, flushes/syncs as specified, renames it to the canonical
  name, and only then publishes `READY`.
- Exactly one Rust ring manager owns the canonical file. A second owner
  attempt returns `ring_owner_conflict`; it must never truncate a live ring.
  The lock mechanism must be proven on Android in Phase 0, not assumed.
- Never resize, truncate, rename, or delete a file while any mapping may be
  live. Rotation creates a new generation file/path and closes the old one
  only after both sides have detached.
- Orderly daemon stop marks the ring `CLOSED`, releases claims, flushes if
  configured, unmaps Rust first, and requires the Kotlin reader to close
  before file cleanup.
- An app upgrade with an older format gets a version error and a new v2
  file. In-flight volatile frames are not migrated and must not be described
  as durable data.

## F-09 — Major: security is absent; magic is not protection

**Evidence.** Neither baseline document has a security section.
[SPIKE-CODE] `Ring::open_consumer` accepts a file on magic and geometry;
its mapping is writable even for the consumer role.

**Required delta.**

- Keep the file under app-private `noBackupFilesDir`, create directories
  and file with owner-only permissions (target mode `0600` for the file),
  and verify the result in an Android instrumentation test.
- Exclude the ring from backup by using `noBackupFilesDir`; a restored
  stale ring must still fail generation/state validation.
- Treat every byte in the file as untrusted input on every attach and read:
  validate header, geometry, counters, frame sequence, length, kind,
  reserved fields, trailer, and CRC before copying.
- CRC and magic detect framing/integrity problems; they do **not**
  authenticate a writer. The trust boundary is the Android app UID/sandbox.
- Do not put API keys, credentials, authorization headers, provider secrets,
  or raw sensitive payloads in the ring. V1 payloads are limited to the
  approved event/dream-frame types from F-01.
- Kotlin's production mapping is read-only. A read-write consumer mapping
  is a no-go for v1.
- Do not expose the absolute path or payload in ordinary UI logs.

## F-10 — Major: no FFI/JNI contract or stale-artifact protection

**Evidence.** [DESIGN] §“What would still be missing for integration” lists
an FFI surface as missing. [GATE] header and §§1–5 show why this matters:
Rust, the generated header, Dart lookups, and the staged `.so` can drift,
and the gate checks freshness, declared exports, Dart lookups, LOAD
alignment, and ABI consistency.

**Required delta — additive surface, subject to Phase 0/1 approval:**

Rust FFI:

- `rga_mmap_ring_state(handle)` — state only: enabled, mode, format,
  generation, geometry, published/consumed counters, depth, claim state,
  last named error. No raw address and no payload.
- `rga_mmap_ring_claim(handle)` — reserves the next frame and returns
  generation, sequence, kind, length, and CRC; or a real empty result.
- `rga_mmap_ring_commit(handle, generation, sequence)` — advances only if
  the claim still matches.
- `rga_mmap_ring_abandon(handle, generation, sequence)` — releases without
  advancing.

JNI for `DreamCycleService`:

- `nativeRingState(handle)`;
- `nativeRingClaim(handle)`;
- `nativeRingCommit(handle, generation, sequence)`;
- `nativeRingAbandon(handle, generation, sequence)`.

Dart `NativeBridge`:

- add `mmapRingState()` only in the first integrated phase;
- do not add a Dart direct mapper or a generic payload push API until a
  named Dart workload exists.

Every phase that changes Rust or `native_bridge.dart` must rebuild and
restage the Android library and then run **[GATE]** as specified in §7.
Adding Dart lookups before restaging is specifically prohibited: that is
the stale-`.so` failure mode the gate was created to catch.

## F-11 — Moderate: signaling, polling, and backpressure ownership are not defined

**Evidence.** [DESIGN] §“Protocol” defines full/empty states, but no wakeup,
polling interval, claim expiry, or consumer-liveness rule. It says
backpressure is the caller's problem without naming the caller for the
proposed workload.

**Required delta.**

- V1 uses polling only at the consumer's existing work boundary; no
  low-latency or “streaming” claim is permitted.
- A claim has a generation and a bounded lease. Lease expiry may abandon
  the claim, but must not advance consumption.
- On `ring_full`, the producer returns the error to its caller and records
  a counted state event. It must not drop the oldest frame, overwrite, or
  silently spill to SQLite.
- Any future eventfd, Binder, MethodChannel, or WorkManager signal is a
  separate design and spike.

## F-12 — Moderate: alternatives were named as a question, not evaluated

**Evidence.** [DESIGN] §“What would still be missing for integration” asks
for a decision versus the existing ring + FFI calls but gives no tradeoff
analysis and does not mention crossbeam or Android `SharedMemory`.

**Delta evaluation.**

| Alternative | Honest tradeoff |
|---|---|
| Keep current slot-locked ring | Lowest risk; safe Rust API and explicit full/empty semantics ([CURRENT-RING] header). In-process only, generic values are moved/copied, no file-backed cross-runtime reader and no crash snapshot. If the workload remains Rust-internal, this is the correct choice. |
| Crossbeam channel | Safe, purpose-built Rust channel semantics and no mmap file lifecycle. Still Rust-process-only, still copies/moves payloads, does not give Kotlin a direct reader, and requires its own dependency/Android spike. It solves Rust concurrency, not the proposed cross-runtime problem. |
| Android `SharedMemory` | Avoids a persistent file and can be shared through Android mechanisms; potentially a better fit for transient same-device IPC. It is Android-specific, has API-level and descriptor-passing design work, and **does not remove the shared-memory ordering problem**. It needs a separate spike and cannot be claimed safer merely because it is an Android API. |
| memmap2 file ring | Works when a file-backed, inspectable, bounded channel is genuinely needed and the reader can be constrained as in this delta. Highest lifecycle/corruption/soundness burden of the options. |

---

# 3. Consolidated corrected protocol

This is the minimum delta an implementation must follow; it does not
authorize implementation by itself.

1. **Roles.** One Rust ring manager is producer and sole writer of header
   counters. One Kotlin reader may map the file read-only. Dart is a state
   observer only in v1.
2. **Publication.** Producer writes frame payload, prefix, and trailer in
   an order specified by the implementation ADR, computes CRC over the
   sequence, length, kind, flags, and payload, and publishes the frame only
   through the Rust manager's synchronization discipline. The spike's
   volatile counter write alone is not accepted as proof.
3. **Validation.** A reader never slices before validating the published
   range and complete frame as required by F-03 and F-05.
4. **Claim.** Rust validates and reserves the next frame. The slot/region
   cannot be reused while claimed.
5. **Copy and commit.** Kotlin copies the payload to owned memory, verifies
   sequence and CRC itself, processes or hands off the copy, and then asks
   Rust to commit. Commit advances counters; abandon does not.
6. **Full/empty.** Empty is an explicit empty result. Full is
   `ring_full`; nothing is overwritten, dropped, or silently redirected.
7. **Corruption.** Any invariant failure quarantines the generation and
   returns a named error. The reader does not skip suspect bytes in search
   of a later frame.
8. **Rotation.** New daemon generation, format change, or unrecoverable
   corruption rotates to a new file/generation after all mappings detach.
   The old file is never truncated under a live mapping.

---

# 4. Required test plan

## 4.1 Already proven by Spike 005 — do not repeat as new evidence

[SPIKE] §“Results” and [SPIKE-CODE] `mod tests` prove, under sequential
same-process calls:

- FIFO order across two mappings;
- a consumer opened after sends can read pending data;
- wrap preserves order;
- full returns `ring_full` and does not overwrite;
- invalid capacity/message sizes are rejected;
- wrong-role calls and bad magic return errors.

## 4.2 Missing tests that block integration

### Rust format and protocol

- all current-ring behaviours mirrored where applicable: empty, FIFO,
  full-with-value/error and no overwrite, wrap, interleaved publish/claim/
  commit, and exact counter accounting ([CURRENT-RING] `mod tests` is the
  baseline set);
- producer and consumer running concurrently, not merely sequentially,
  with every frame's sequence and CRC checked;
- two separate host processes mapping the same file;
- claim → crash simulation → same sequence redelivered;
- commit → no redelivery;
- second owner returns `ring_owner_conflict`;
- producer restart rotates generation and does not present stale frames
  as new.

### Corruption — every case must return a named error, never panic

- bad magic;
- unsupported version;
- static-header CRC mismatch;
- file too short, too long, or truncated after mapping setup;
- capacity zero, non-power-of-two, below minimum, or inconsistent with
  total size;
- `read_total > write_total` or occupancy greater than capacity;
- frame sequence too old, too new, or duplicated;
- frame length beyond maximum, beyond published bytes, or beyond the
  data area;
- prefix/trailer sequence mismatch;
- payload CRC mismatch;
- nonzero v2 reserved field;
- repeated wrap markers or wrap padding that would loop forever;
- header left in `INITIALIZING`;
- counters changed between first and second validation reads.

### Kotlin / Android

- instrumentation test in which Rust creates a fixture ring and Kotlin's
  `MappedByteBuffer` reader claims, reads, validates, commits, and abandons
  known frames;
- little-endian order proven with known multi-byte values;
- read-only mapping proven by attempting no writes in production code and
  by API/design review;
- reader close and service destroy do not delete or truncate a live file;
- file and directory permissions verified on device;
- service restart and app-process restart produce the specified generation
  behaviour;
- concurrent producer load while Kotlin reads, with no sequence, CRC, or
  duplicate-delivery violations beyond the stated at-least-once claim rule.

### Performance — only if performance is the justification

- Measure the existing FFI/JNI path and the mmap path on the A16 for the
  actual payload sizes from F-01.
- Report sample count, payload size, median and tail results exactly as
  measured. No “sub-millisecond”, “zero-copy speed”, or throughput claim
  may be made from host tests or from the shape of the API.

---

# 5. Phased implementation and go/no-go gates

## Phase 0 — workload and soundness proof (spike only)

Work:

- name the workload and canonical daemon owner (F-01, F-07);
- prototype the Kotlin read-only mapper and claim/commit boundary;
- prove Android file path, owner lock, mapping order, and permission
  behaviour on the A16;
- decide whether direct reading is viable or the design falls back to a
  Rust-mediated copy.

**Go only if:** one workload, one owner, one consumer, and a passing A16
reader proof exist.
**No-go if:** the only justification is “zero-copy”, no production traffic
needs the channel, or direct Kotlin reading cannot be validated.

## Phase 1 — v2 format in Rust only

Work:

- implement the v2 header/frame validation in an isolated module or spike;
- add the corruption and concurrent-process tests in §4;
- keep the current slot-locked ring and all production paths unchanged.

**Go only if:** all new tests pass and corruption never panics.
**No-go if:** the protocol still depends on an uncritiqued volatile/fence
assumption for its correctness claim.

## Phase 2 — Rust core lifecycle and mediated control surface

Work:

- add the ring manager behind a default-off config flag;
- add only the FFI/JNI state and claim/commit surface in F-10;
- retain the old ring and existing FFI/JNI paths as fallback;
- rebuild and restage `libdaemon.so`.

**Mandatory artifact gate:** run
`~/workspace/rich_gang_ai/tools/release_gate.sh --suites` after restaging.
It must pass before this phase may be called integrated.

## Phase 3 — Kotlin direct reader

Work:

- add the read-only `MappedByteBuffer` reader in the service path;
- wire claim → copy/validate → commit/abandon;
- run Android instrumentation and restart tests on the A16.

**Mandatory artifact gate:** run
`~/workspace/rich_gang_ai/tools/release_gate.sh --suites` again after any
Rust, JNI, or `native_bridge.dart` change in this phase.

**Go only if:** the A16 tests pass under concurrent load and service
restart.
**No-go if:** the reader requires Kotlin to write shared counters, the
file must be truncated under a live mapping, or validation can be bypassed
by a torn frame.

## Phase 4 — one workload, default-off soak

Work:

- enable the ring for the single Phase 0 workload only;
- keep the mediated fallback available;
- expose state through Dart, not direct payload mapping;
- record full, corruption, claim-expiry, and rotation counts exactly as
  observed.

**Mandatory artifact gate:** run
`~/workspace/rich_gang_ai/tools/release_gate.sh --suites` on the exact
artifact used for the soak.

**Go only if:** observed behaviour matches the delivery and corruption
rules and the workload benefit is demonstrated.
**Rollback:** disable the config flag; the old FFI/JNI and slot-ring paths
remain authoritative.

## Phase 5 — separate adoption decision

Migrating another workload, removing the current ring, or calling the
channel “zero-copy” in any user-facing or sales material requires a new
Richard decision and new evidence. None follows automatically from
Phase 4.

---

# 6. Blast radius if implementation is later approved

| Surface | Expected impact | Reason |
|---|---|---|
| New Rust mmap-ring module | **High, but contained if isolated** | New unsafe mapping, format, validation, lifecycle, and concurrency discipline. |
| `rich_gang_ai_core/src/lib.rs` | **Medium** | Daemon config, canonical owner, start/stop, and generation lifecycle. |
| `rich_gang_ai_core/src/ffi.rs` | **Medium–high** | Additive symbols are easy to declare but dangerous if the staged binary drifts; [GATE] §§1–5 addresses the artifact risk. |
| `rich_gang_ai_core/src/jni_bridge.rs` | **Medium–high** | New claim/commit calls and panic/error boundaries for the service. |
| `flutter_app/lib/core/native_bridge.dart` | **Medium–high** | Any new unconditional lookup can fail app boot if the `.so` is stale; [GATE] §3 specifically checks Dart lookups. |
| `DreamCycleService.kt` | **High** | It currently boots its own daemon handle with `"{}"`; path supply, ownership, reader lifetime, and destroy ordering all change. |
| `MainActivity.kt` | **Medium, conditional** | Only if it becomes responsible for supplying the app-private path or coordinating service start order. |
| `AndroidManifest.xml` | **Low if unchanged** | No new permission is needed for app-private internal storage. Splitting the service into another process would raise this to high and requires a new design. |
| Existing `ring_buffer.rs` | **Low in Phases 0–4** | It remains in place as the Rust-internal fallback and is not renamed or relabelled. |
| SQLite store / topology | **None planned** | The ring is not a durable store and must not replace SQLite semantics. |
| Build/release process | **High operationally** | Every Rust/JNI/Dart bridge change requires rebuild, restage, and [GATE], not merely green unit tests. |

---

# 7. Release-gate requirement — explicit audit gap and correction

**Gap.** Neither [DESIGN] nor [SPIKE] mandates
`tools/release_gate.sh` in any implementation phase. That omission matters
because [GATE] header records the exact prior failure: green suites with a
stale staged binary whose exports did not match Dart's unconditional
lookups.

**Correction.** Every implementation phase in §5 that touches
`rich_gang_ai_core/`, `jni_bridge.rs`, `DreamCycleService` JNI, or
`native_bridge.dart` must:

1. rebuild the aarch64 release `libdaemon.so`;
2. restage it into
   `flutter_app/android/app/src/main/jniLibs/arm64-v8a/libdaemon.so`;
3. run `~/workspace/rich_gang_ai/tools/release_gate.sh --suites`;
4. record the gate output and the staged SHA-256 in the phase record;
5. stop and fix the artifact if the gate exits nonzero.

The gate's own checks — staged/built SHA equality, Rust-declared exports
present, every Dart lookup resolving, LOAD `Align 0x4000`, and Rust/Dart ABI
match ([GATE] §§1–5) — are necessary but not sufficient for this feature.
They do not prove the mmap protocol, Kotlin reader, Android permissions, or
device behaviour; §4's tests remain mandatory.

---

# 8. Final audit position

- **Retain** Spike 005 as a successful spike of a bounded SPSC byte-ring
  format under sequential, same-process mappings ([SPIKE] §“Results”).
- **Do not retain** any implication that volatile counter access, the
  64-byte header, or the 4-byte record prefix is production-ready
  ([DESIGN] §“Protocol”, §“Layout”, and §“Crash rules”).
- **Do not integrate** until Phase 0 names a real workload and proves the
  Kotlin reader and ownership model on device.
- **Do not call it zero-copy** without naming the exact boundary and the
  copies that remain. On the evidence in [SPIKE-CODE] `Ring::send` and
  `Ring::recv`, the honest current label is **“file-backed mmap SPSC byte
  channel (spike)”**.
- **Do not bypass** `~/workspace/rich_gang_ai/tools/release_gate.sh` for
  any later implementation phase.
