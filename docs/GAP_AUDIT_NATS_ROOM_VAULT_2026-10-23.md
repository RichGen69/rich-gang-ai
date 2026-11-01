# GAP AUDIT — NATS / The Room Control Plane / Aquarius / DannyAISweepVault paste (2026-10-23)

Paste saved verbatim: `docs/PASTE_NATS_ROOM_VAULT_2026-10-23.md`.
Posture (same as v4.0, v5.0, Tier-8 arbitrage pastes): supplied material to
audit, NOT a build order. **Nothing in this paste was built over the verified
codebase, integrated, deployed, or run against any live service or real
funds.** Richard's standing rules apply unchanged: no mock data/math, no
hallucination, publish gate stands, `docs/SALES_LISTING_DRAFT.md` remains
the only pitch copy.

Evidence method: greps over the actual workspace source (`.rs`, `.dart`,
`.toml`, `.py`, excluding docs and spikes), `rich_gang_ai_core/Cargo.toml`
read directly, Danny's entry in `flutter_app/assets/characters.json` read
directly, and a careful line read of the pasted Solidity.

---

## A. Architecture vs reality

- **NATS JetStream: NOT BUILT.** Zero occurrences of "nats" anywhere in the
  app's source (Rust, Dart, TOML, Python). No NATS server, no JetStream
  streams, no subject schema implementation. The core's actual dependency
  list (`rich_gang_ai_core/Cargo.toml`): serde, serde_json, parking_lot,
  petgraph, rusqlite (bundled), memmap2, log, android_logger, jni. There is
  no async runtime in the shipped core at all.
- **Tokio: NOT INTEGRATED, by design decision.** Spike 003 passed at
  compile level only. `docs/DESIGN_TOKIO_INTEGRATION_2026-10-23.md`
  concludes, verbatim in substance: "nothing in the current codebase needs
  it today" and recommends **do not integrate tokio now**. The paste's Rust
  assumes tokio + async-nats as its foundation — the exact integration the
  design doc deferred. The paste does not change that analysis: a NATS
  client is a named *future* consumer class (networked mesh), not a present
  need.
- **Server mesh vs the actual product: CONTRADICTED by the product's own
  architecture.** The paste describes a multi-process server system: a NATS
  broker, a Rust control plane, a Python LiveKit Agents worker on LiveKit
  Cloud, an on-chain contract. Rich Gang AI is a **private, on-device
  Android app** (Flutter/Dart + Rust `libdaemon.so` + Kotlin service) whose
  verified architecture runs state, affect, memory, and reasoning
  orchestration on the phone. There is no server component in the shipped
  product for this mesh to attach to, and standing context records the app
  as on-device by design. Adopting the paste's topology would be a new
  product architecture, not an upgrade to this one.
- **Privy TEE / RISC Zero: ABSENT.** Zero occurrences in source. Named only
  in the paste's diagram. Nothing in the pasted code — including the vault
  contract — uses, references, or proves either. This matters most for the
  vault (Section C): the diagram claims the agent key lives behind a TEE;
  no code in the paste puts it there.
- **Cartesia TTS: NOT WIRED.** Zero occurrences in source. The app's real
  voice stack is Deepgram (Nova-3 STT + Aura TTS client), ElevenLabs
  (per-character casting), and system TTS fallback via flutter_tts
  (`flutter_app/lib/core/deepgram_client.dart`, `voice_engine.dart`). The
  paste's Cartesia Sonic-2 pipeline, and its voice IDs (Section B), are
  unverified and unwired.
- **"The Room" name collision.** In the paste, "The Room" is a Rust NATS
  control plane. In the app, The Room is the Flutter home/roundtable
  surface (`flutter_app/lib/views/the_room.dart`, `roundtable_view.dart`)
  — no control plane, no message bus, no capability registry. Same name,
  unrelated systems. Any future discussion must say which one it means.
- **v5 UDP mesh relation.** The v5 spec's UDP multicast mesh
  (224.0.0.123:8888) was already audited NOT BUILT (`GAP_AUDIT_V5_2026-10-22.md`
  Tier 6: "Crew Link flag only, no transport"). This paste is, in effect, a
  second, incompatible design for the same unbuilt idea (agent-to-agent
  coordination) using NATS instead of UDP. It inherits the same status:
  a design for a transport that does not exist here, and it does not
  supersede the v5 finding.

## B. Code reality

- **The Rust Room snippet cannot compile as pasted.** It is truncated
  mid-signature: `pub async fn route_intent(&self,` runs directly into the
  next file's comment (`// lib/avatar/liveavatar_view.dart`). No crate,
  no Cargo.toml, no registration handler, no subscription setup, no main.
  It is a fragment, and `route_intent` — the one function the whole design
  turns on — is the part that's missing.
- **The capability model is unenforced as pasted — this is the audit's
  central code finding.** The schema says every message carries
  `{ from, ts, capability, signature }` and that capability "claims [are]
  enforced by Room." In the entire paste, the word "signature" appears
  exactly **once** — that schema header line. There is no signature
  verification code anywhere: no key registry, no verify call, nothing.
  Worse, **no registration code is pasted at all** — nothing shows who
  writes into the `agents` map that `check_capability` reads from, or how
  a registering agent's claimed `Capabilities` are authenticated.
  `check_capability` itself is internally consistent (it correctly reads
  the registry rather than the message), but a check against a registry
  that any unauthenticated process may be able to write is not
  enforcement. As pasted, any process that can publish to
  `room.agents.register.*` could plausibly register itself with
  `Capabilities::danny()` and pass every check. The trust-boundary diagram
  ("The Room → vault: NO PATH") is a claim about this unenforced layer.
- **Dart `LiveAvatarView` is not drop-in compilable.** Its
  `firstWhere(..., orElse: () => null)` on non-nullable element types
  (LiveKit participants / track publications) does not type-check under
  null-safe Dart as written, and it references an undefined `kLabelStyle`.
  The app already has its own LiveAvatar path
  (`flutter_app/lib/core/liveavatar.dart`, `livekit_service.dart`,
  `avatar_call_view.dart`) built and verified at code level; this snippet
  is not it.
- **Python voice stack: fragments calling undefined functions.** The
  worker calls `broadcast_avatar_state` (undefined in the paste); the
  WebRTC transport calls `voice_turn_from_track` and
  `avatar_channel_handlers` (undefined); the voice pipeline calls
  `stt_stream` and `tts_stream` (undefined). `RTCPeerConnection` is given
  both `configuration=` and an invalid `rtcConfiguration=None` kwarg.
  There is no Python voice worker in this project at all — the only Python
  in the tree is the HTML/store build scripts. `reasoning.router`
  (imported by the persona tests) also does not exist here.
- **The worker code is pasted twice, verbatim** — and the latency tables
  disagree with each other. Three different end-to-end figures appear:
  ~650–850 ms (target < 800 ms p95), ~550–750 ms (target < 650 ms p95),
  and ≤ 570 ms ("sum of critical path"). They cannot all be the budget.
- **All latency numbers are TARGETS in the paste; zero measurements
  exist.** Phrases like "we benchmarked in the previous cycle" are claims
  inside the supplied material with no benchmark artifact anywhere in this
  workspace. Per Richard's rule these figures must never be quoted as
  achievements — they are unverified targets from an unverified stack
  (Cartesia isn't even wired).
- **Invented voice identifiers.** `cartesia.TTS(..., voice="danny-v1-male-us-mid")`
  and `VoiceConfig.voice_id = "danny-male-us-mid"` are presented as config,
  but no Cartesia account, catalog lookup, or documentation in this
  workspace verifies either ID exists. Same class as the ElevenLabs rule
  applied to Danny today: an unverified voice ID is an invented voice ID,
  and it must never be presented as real or cast.
- **HeyGen / LiveAvatar mixing.** The app's shipped avatar path is
  LiveAvatar (HeyGen's separate video API curl was flagged do-not-use in
  the v4 audit). The paste uses LiveAvatar for sessions but labels the
  diagram box "HeyGen avatar," reads `HEYGEN_LIVEAVATAR_ID` from env,
  and attaches a "TRAIGA / HB 149" compliance note requiring a watermark
  in a `DannyAvatar.tsx` component **that does not exist in this
  codebase** (no `.tsx` files at all; TRAIGA was already audited NOT
  BUILT in the v5 audit, Tier 7). The compliance claim is therefore
  unanchored: it cites rules and a component that aren't here.

## C. The vault contract — DannyAISweepVault

Careful read of the contract exactly as pasted. Bottom line first:
**DO NOT DEPLOY.** Unaudited supplied material with a real-money blast
radius, in the same standing category as the Tier-8 arbitrage daemon.

**Checking the paste's own claimed fixes:**

- **D1 (hash collision) — fix is real and correctly applied.** `_commit`
  now hashes the dynamic payload separately (`keccak256(payload)`) and
  `abi.encode`s fixed-size fields, which does remove the
  `abi.encodePacked` field-boundary ambiguity the defect table describes.
  This specific claim checks out. Caveat the table doesn't mention: the
  chain hash still folds in `block.number` and `block.timestamp`, so the
  "audit chain" value is partly a function of public, predictable block
  data — it orders events, but it is not a commitment scheme and proves
  nothing about *who* authorized an event beyond the emitting transaction.
- **D2 (honeypot dead code) — fix verified as pasted.** No honeypot key or
  modifier exists in the pasted contract. True — of this paste. It also
  means the defect table describes a *different, earlier version* of the
  contract that was not supplied; only this version can be assessed.
- **D3 (guardian) — the mechanism exists; the hole is process, not code.**
  `setGuardian()` exists and rejects the zero address. But `guardian`
  still starts as `address(0)`, the constructor cannot set it, and nothing
  in the contract, the paste, or this workspace records a deployment
  checklist step that sets it. Until the owner calls `setGuardian`,
  halt-by-guardian is silently dead — exactly the failure mode D3 names,
  moved from "impossible" to "one forgotten transaction away." Acceptable
  only with a documented, verified post-deploy step; none exists here.

**Findings beyond the pasted defect table:**

- **`checkAndSweep` is permissionless.** Anyone can call it at any time
  once the balance reaches 500 USDC, forcing a sweep of the *entire*
  balance to the owner. Funds cannot be redirected (destination is the
  immutable owner), so this is not a theft vector — but it is a griefing /
  timing vector: a third party chooses when the operator's funds move,
  every time the threshold is crossed. A sweep function with no caller
  restriction on real money should be a deliberate, documented choice; the
  paste never mentions it.
- **`auditState()` conflates paused with halted.** It returns
  `isHalted = paused`, but `paused` is also set by the owner's plain
  `pause()`. A reader of the audit state cannot distinguish an emergency
  halt (with reason) from a routine pause. For a contract whose selling
  point is its audit trail, the audit view itself blurs the most
  important distinction it has.
- **`unpause()` erases halt history from state.** It zeroes `haltReason`
  and `haltedAt`. The `EmergencyHalted` event remains in the chain's logs,
  but the contract's own state — the thing `auditState()` and
  `room.state.vault` report — shows no trace that a halt ever happened.
  That sits badly next to the paste's "shadow log / audit chain" claims
  and next to Danny's own append-only accountability design shipped in
  this app today.
- **The agent key can halt the vault itself.** `emergencyHalt` accepts
  `dannyAgentKey`. A compromised agent key therefore has a denial-of-service
  lever as well as a spend lever (owner can unpause, so
...[truncated 7245 chars]