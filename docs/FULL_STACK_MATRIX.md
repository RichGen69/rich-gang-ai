# FULL-STACK COMPLETENESS MATRIX — Rich Gang AI / THE ROOM

Created 2026-10-21 (Tier-10 build). Every feature/claim raised across
Richard's messages in this thread, with an honest status:

- **Built+Verified** — implemented and covered by a passing automated test or a previously documented live check.
- **Wired+Unverified** — code is wired end-to-end but has not been exercised live (needs keys / a device / a live call).
- **Registry-or-Doc-Only** — exists as data or documentation only; no functioning feature behind it.
- **Gated-Needs-Richard** — blocked on a decision, key, data, or setting only Richard can supply.
- **Not-Built** — does not exist. Not claimed anywhere in shipped UI/copy as existing.

The single stack of this project is **Flutter/Dart + Rust**. There is
no TypeScript, React, FastAPI, or Python backend in this repository.

## Rust core (`rich_gang_ai_core/`)

| Item | Status | Evidence / notes |
|---|---|---|
| Circuit breaker (`circuit_breaker.rs`) | Built+Verified | Synchronous std-only 3-state breaker (Closed/Open/HalfOpen), failure threshold, Instant-based recovery timeout, `record_latency` with >250 ms as a failure signal. 8 unit tests. Crate-internal (see Integration note). This is the **daemon-side** breaker primitive. |
| Edge inference (`edge_inference.rs`) | Built+Verified (as an explicit error path) | Config struct + `initialize()`/`execute()` that return explicit errors: model file missing, and no GGML/ONNX/WebGPU runtime linked. 3 unit tests assert no fabricated response is ever returned. Actual local LLM inference: **Not-Built**. |
| Atomic ring buffer (`ring_buffer.rs`) | Built+Verified | Atomic head/tail, power-of-two capacity, slot-Mutex storage — documented in-code as **atomic, slot-locked; NOT lock-free, NOT zero-copy**. FIFO, full/empty semantics. 6 unit tests. |
| SHA-256 state hashing for the ring buffer | Not-Built | `sha2` is not a dependency of this crate; no hash claim is made. The crate's existing vector hash is FNV-1a **lexical** (token overlap) — not cryptographic, and never labelled as such. |
| Watchdog supervisor (`watchdog.rs`) | Built+Verified (detection only) | Worker registry + heartbeat timestamps + `stale_workers(threshold)` report. 5 unit tests. **No thread respawn** (a library crate owns no worker threads) and **no hardware watchdog** — a host-side consumer does not exist yet. |
| Tamper-evident audit logging (hash chain) | Not-Built | Would require a real cryptographic hash (see SHA-256 row). Existing logging (`logging.rs`) is plain `log` + an Android panic hook — useful, but not tamper-evident, and not labelled as such. |
| Secure IPC | Built+Verified (as FFI) | The app's real IPC is **FFI/NativeBridge** (`rga_*` exports, ABI 2) + JNI for the Kotlin service. **Unix domain sockets / named pipes: Not-Built and not appropriate for the Android app** — the pasted spec's socket language is not implemented and not claimed. |
| Pre-cognition / speculative ring buffer | Not-Built | The pasted `pre_cognition.rs` snippet was a placeholder (`write_speculative` did nothing). Not ported. The ring buffer above is a general queue, not a speculative-token engine. |
| Hardware memory isolation / zero-trust attestation | Not-Built | No attestation, no hardware-backed isolation exists in the crate. Agent separation is by data structure (per-persona state, per-character mind stores), not hardware. |
| Dream cycles, lexical memory, scene/affect (pre-existing) | Built+Verified | Milestones 1–3 + later sessions; cargo tests cover FFI, scene, facts, vector. Broadcasts are factual-only. |

### Integration note (FFI discipline)

The four Tier-10 Rust modules (`circuit_breaker`, `edge_inference`,
`ring_buffer`, `watchdog`) are `pub mod`s compiled into the crate and
covered by unit tests, but are **crate-internal: no new FFI exports**.
Reason: ABI is versioned (currently 2) and every export needs a
cbindgen header update plus matching Dart/Kotlin lookups. Nothing on
the Dart side needs to call these modules today — the Dart router
makes the actual cloud calls (the Rust daemon never did), so a Dart
FFI bridge to a Rust breaker would be a second, contradictory source
of routing truth. **Division of responsibility:** Rust breaker =
daemon-side primitive, tested, ready for a future Rust-side caller;
Dart `Tier10SystemController` = router-side telemetry/state for the
routing that actually happens in Dart. Their state models mirror each
other (Closed/Open/HalfOpen ↔ cloud/edge/probe, same 250 ms rule) and
do not contradict.

## Router & failover (Dart)

| Item | Status | Evidence / notes |
|---|---|---|
| Cloud providers → Ollama fallback | Built+Verified (pre-existing) | `inference_router.dart`: NVIDIA primary (probe, RPM gate, rate-limit/account-block back-off), or OpenAI/Gemini when selected in Settings; local-only tasks never leave device. |
| Tier-10 controller wiring | Built+Verified (this build) | Router now reports measured latencies (Stopwatch), cloud failures, and Ollama-fallback activations to `Tier10SystemController`; each router owns one by default, injectable for sharing. |
| Automated failover latency claim ("sub-5 ms") | Not-Built (as a claim) | No benchmark exists. The Dart fallback is a routing decision after a failed/probed call — its cost is the failed call's cost, not 5 ms. Claim lives only in Richard's prospectus, flagged unverified. |
| Deepgram STT/TTS client | Wired+Unverified | `deepgram_client.dart` built against documented API; **model discrepancy: built client uses Nova-3 STT + Aura-2 TTS — Richard's pasted documents say "Nova-2" and "flux-kit-en v2". The code is the truth; the documents are stale.** No live call made (no key in this VM); no mic capture wired to it. |
| ElevenLabs TTS | Wired+Unverified | VoiceEngine + Prosody; needs Richard's key + per-character voice IDs confirmed in his account. System-TTS fallback is reported in UI, never passed off as premium. |
| LiveAvatar (HeyGen successor) video | Wired+Unverified | `liveavatar.dart` FULL mode from official OpenAPI; needs Richard's LiveAvatar key + per-character LiveAvatar avatar IDs. Legacy HeyGen streaming also present (Wired+Unverified); HeyGen token route probed 404 in a prior session. |
| LiveKit | Wired+Unverified | `livekit_service.dart`, on-device HS256 JWT minting (token test passes), behind the Crew Link flag (default off). No live room exercised. |
| WebRTC mesh / jitter compensation | Not-Built (as a custom mesh) | LiveKit/LiveAvatar SDKs carry their own WebRTC. No custom mesh, jitter buffer, or packet-telemetry pipeline exists in this codebase. |
| Multi-model routing (Grok 4.7, Claude Opus 5.5, Gemini "3.5 Pro", GPT-5.6 Luna, GPT-6 Astra beyond the OpenAI slug field) | Not-Built | Only **NVIDIA / OpenAI / Gemini / Ollama** are wired providers. Names from Richard's pasted specs are not providers in this code. The OpenAI model slug is a Settings field for Richard to confirm in his own dashboard. |

## Agents & roster

| Item | Status | Evidence / notes |
|---|---|---|
| Original 9 characters | Built+Verified | Full entries: portrait, voice casting, PAD baselines, roles. Tests assert their data is retained. |
| 13 Tier-10 expansion agents | Registry-or-Doc-Only | Present in `characters.json` + `daemon_config.json` personas with id/name/title/zodiac-or-celestial/universe (where supplied) and `status: registry_only_unconfigured`. **No portraits, no voice casting, no affect baselines** — parser defaults safely and the UI/HTML label them unconfigured. They must not be marketed as finished. |
| Zodiac/celestial assignments | Registry-or-Doc-Only | Added as data fields exactly as Richard supplied (incl. Ophiuchus, Chronos, Astraea, etc.). |
| Tammy vs The Oracle | Resolved 2026-10-22 | Tammy (original roster) keeps the title "The Oracle"; the expansion character is now named "The Oracle of Nocturna" (Nocturna, title "Nocturna Dream Analyst") so the two never share a name. Resolved at Richard's instruction, test-locked. |
| 21+ age gate | Built+Verified (confirmation-only) | `AgeGate`: user confirms "I am 21+", stored as a local flag. Applies to Kelly (see swap note), Shawna, Ruby. **Swap note:** during this build the Kelly entry was concurrently changed (another session, at Richard's direction per `flutter_app/test/roster_asset_test.dart`) from `cougar_kelly`/"Cougar Kelly" to `crazy_kelly`/"Crazy Kelly" (title "The Wildcard", Vice City core, own portrait). That change is retained. Two flags for Richard: (1) her asset zodiac is Scorpio, while the Tier-10 list assigned Taurus to Cougar Kelly and Scorpio to Dan — Dan also carries Scorpio; (2) her new title "The Wildcard" overlaps the expansion character The Wildcard (Sector Zero). Neither was silently "fixed" over the concurrent change. **Resolved 2026-10-22 by Richard's decision:** keep Crazy Kelly, drop Cougar Kelly entirely; Kelly's zodiac is now Taurus (Dan keeps Scorpio alone) and her title is now "The Neon Wildcard" (distinct from the Sector Zero Wildcard). The Tammy/Oracle overlap was resolved later on 2026-10-22 (see its own row above). |
| JWT / biometric / hardware age assurance | Not-Built | No JWT middleware, no biometric check, no verified age method exists. The pasted `age_gate.dart` (local_auth) snippet was **not** ported — it also only proved device-owner presence, not age. |
| Roundtable sequential context | Built+Verified (pre-existing) | TurnEngine + session: later speakers receive earlier speakers' actual lines; tests cover turn picking. Private reasoning vs public output separation: think-steps are structured summaries, not exposed raw chain-of-thought. |

## Frontend (Flutter)

| View / console | Status | Notes |
|---|---|---|
| THE ROOM (hub: hero, live strip, cast, setup & health, room controls) | Built+Verified | `the_room.dart`. Now also hosts the Tier-10 HUD card fed by `InferenceRouter.shared`'s controller + the real registry count. |
| Tier-10 HUD | Built+Verified | `tier10_hud.dart` + `tier10_system_controller.dart`; widget test covers the honest "not measured yet" state. Black-and-gold via Obsidian theme (#07070f / #d9b56b family). |
| Chat (picker + 1:1 chat), Roundtable ("Table"), Memory nav, Settings | Built+Verified (pre-existing) | Bottom nav: Room / Chat / Table / Memory / Settings. |
| Avatar call view, 3D Stage view, Interrogation, Dream Broadcast, Cold Open | Built / Wired+Unverified | Views exist and analyze clean; on-device behaviour is unverified (APK gate). Stage: no character GLBs exist — demo robot only, labelled. |
| HUB console (as a separate page) | Not-Built (as a separate page) | The Room screen is the hub. The "HUB" label in Richard's frames ≠ a distinct HUB view in code. |
| CREW console (separate roster-management page) | Not-Built (as a separate page) | Roster management today = cast grid in The Room + Chat picker. No standalone CREW view. |
| STUDIO console (Aquarius media generation) | Not-Built | No STUDIO view exists. HeyGen video-generation client exists in core (Wired+Unverified) without a studio console. |
| CLOUD console (infrastructure metrics page) | Not-Built | No CLOUD view. The closest real surfaces: SETUP & HEALTH card + Tier-10 HUD card in The Room. NEXUS chips in The Room are labels, not a console. |
| MEMORY console (Chronos timeline page) | Registry-or-Doc-Only | A "Memory" nav destination exists in the scaffold; a dedicated multiverse timeline/continuity console as specced does not. Mind persistence itself is real (next section). |
| ACCOUNT console (billing & licensing) | Not-Built | No accounts, billing, or licensing exist in the app. Settings is not an account page. |

## Memory & multiverse

| Item | Status | Evidence / notes |
|---|---|---|
| Persistent mind (MindStore) | Built+Verified (pre-existing) | On-device SharedPreferences persistence: affect states, self-models, interactions; restored across runs, honestly labelled fresh vs restored. |
| Self-model: affinities, learned interests, reflections, open loops | Built+Verified (pre-existing) | `self_model.dart` — relationship tracking **does** exist in this simple inspectable form: per-pair affinity moved by real roundtable exchanges, prompt-visible summaries. |
| Multiverse Memory Engine (specced module: biographies, episodic retrieval, continuity checking, canon editing, backup/recovery) | Not-Built (as that module) | No module by that name/powers exists. What exists: characters' `core` text as supplied, Rust lexical recall (token overlap — **not** semantic/episodic retrieval), dream consolidation summaries. Fictional origin biographies for the expansion cast were supplied by Richard in prose (Empress/Outlaw/etc.) but are **not** wired as per-character biography stores; the registry carries only his one-line roles for them, by design (no invented backstories). |
| Character origin universes (Ashfall-77, Veloria, Sector Zero, Nocturna, Meridian-9, Imperium-12) | Registry-or-Doc-Only | Stored as the `universe` field for the 6 expansion agents Richard assigned one. No simulated "home universe" features exist. |

## Brand, stacks & publishing

| Item | Status | Notes |
|---|---|---|
| Brand hierarchy (Rich Gang AI Productions → THE ROOM / SDK / Studio / Intelligence / Cloud / Marketplace / Enterprise) | Registry-or-Doc-Only | Recorded as Richard's brand architecture (this matrix + prospectus doc). Only **THE ROOM** exists as a product. No SDK package, Studio product, Cloud hosting, Marketplace, or Enterprise licensing exists. |
| FastAPI backend + React/TypeScript frontend (Richard's pasted snippets: Freak Show AI v3, `routes/agents.py`, Room.tsx, room.css) | **Not-Built — decision needed** | This is a **second, incompatible stack** that does not exist in this project (Dart + Rust only; no TypeScript anywhere). It was NOT silently built. **Decision needed from Richard: keep Flutter/Rust as the single stack, or commission a separate web backend as its own project.** |
| HTML website (`html_build/`) | Built+Verified | Regenerated 2026-10-21 from the 22-entry registry with honest registry-only labelling; tag balance + roster verified programmatically. Still a local file — **not hosted/published**. |
| Android APK | Gated-Needs-Richard | Build blocked on the VM `other_tcp` permission (Richard's settings change). Not device-verified. |
| Prospectus / listing copy | Registry-or-Doc-Only | Richard's prospectus saved verbatim in `docs/PROSPECTUS_RICHARD_SUPPLIED.md` with an unverified-claims header. No listing created. Publish only via `docs/PUBLISH_GATE.md`. |
| Availability / SLA claims (99.9999%, zero-downtime, sub-5 ms) | Not-Built (as claims) | No measurement, monitoring, or SLA infrastructure exists. Never to appear in copy as verified. |
