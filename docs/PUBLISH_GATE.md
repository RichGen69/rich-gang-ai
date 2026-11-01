# PUBLISH GATE — Rich Gang AI / THE ROOM

Richard's rule (2026-10-21): the app, platform, and website are published
**only** when finished to an elite Hollywood-grade, cinematic, flagship,
enterprise, commercial level. Until **every** item below passes with
evidence, **no publish action is taken**: no Acquire.com listing, no app
store submission, no public hosting, no public deployment of any kind.

Status at creation (2026-10-21): **GATE CLOSED — not ready to publish.**
See `docs/TIER10_BUILD_2026-10-21.md` for the item-by-item state.

## The checklist — ALL must pass

### Code & verification
- [ ] `cargo test` green in `rich_gang_ai_core` (final counts recorded in the build doc). — Status 2026-10-23: green 74/74 in the finish-build pass, then red the same afternoon while another workstream's ring edit is mid-flight (lib-test compile error in their new ring test); not final until that workstream lands and the suite is re-run. See `docs/BUILD_FINISH_2026-10-23.md`.
- [x] `flutter analyze` green under the strict analysis options (strict-casts / strict-inference / strict-raw-types — not loosened to pass). — Verified 2026-10-23: "No issues found" (`docs/BUILD_FINISH_2026-10-23.md`).
- [x] `flutter test` green in `flutter_app`. — Verified 2026-10-23: 43/43 passed (`docs/BUILD_FINISH_2026-10-23.md`).
- [ ] No mock data, simulated responses, or hardcoded telemetry anywhere in shipped code (Richard's standing rule).

### Build & device
- [ ] APK actually builds — requires Richard to change the VM's `other_tcp` direct-network permission from Deny to Ask in Muse Settings → Permissions → Direct network protocols, then approve the Gradle daemon card. No workaround substitutes for this.
- [ ] APK installed and **device-verified on Richard's A16**: cold open, chat via a real provider call, roundtable, voice, dream cycle, and the Tier-10 HUD all exercised on device — not just analyzed/tested in the VM.
- [ ] `libdaemon.so` rebuilt from the current Rust sources (including the Tier-10 modules) and restaged, with exports verified against Dart/Kotlin lookups.

### Roster truth-in-marketing
- [ ] Every **marketed** agent is fully configured: portrait, voice cast (confirmed in Richard's own ElevenLabs account), and affect tuned. Registry-only agents (13 at gate creation) are either fully configured before launch or **excluded from marketing copy** — they may not be advertised as finished characters.
- [x] The Tammy / "The Oracle" title overlap is resolved by Richard (rename, retitle, or explicit acceptance) before the 22-agent roster is marketed. — Resolved 2026-10-22 at Richard's instruction: Tammy keeps "The Oracle"; the registry-only entry is renamed "The Oracle of Nocturna". (The Kelly/Wildcard overlap and Kelly's zodiac were resolved the same day: Crazy Kelly, "The Neon Wildcard", Taurus.)

### Providers & services
- [ ] Every provider key is verified by a **live call**, not merely saved: NVIDIA/OpenAI/Gemini (whichever is marketed), Ollama local path, ElevenLabs TTS, Deepgram, LiveAvatar (with per-character avatar IDs that belong to LiveAvatar — HeyGen IDs do not carry over).
- [ ] Any service named in marketing (WebRTC calling, video avatars, web search) has been exercised end-to-end in the shipped build.

### Age assurance & safety
- [ ] 21+ access uses a **real verified age-assurance method** before any 21+ character is marketed or unlocked. The current gate is confirmation-only (a user tapping "I am 21+") — that is **not** verified age assurance and does not satisfy this item.
- [ ] Security/privacy review completed: key storage (Keystore-backed secure storage), IPC/FFI surface, data leaving the device per provider, and the Crew Link flag state.

### Claims & copy
- [ ] Every prospectus claim is either **verified with evidence** or **removed** from listing/store copy. Known unverified claims at gate creation: sub-5 ms failover benchmark, memory-mapped GGML/ONNX/WebGPU edge weights, 99.9999% availability, hardware JWT age assurance, "22 fully-configured agents", Deepgram "Nova-2" (the built client is Nova-3 + Aura).
- [ ] Valuation figures in any listing are presented as Richard's asking position, not as appraised/verified value.

### Website
- [ ] HTML website regenerated from the **final** registry, verified for tag balance, embedded assets, and honest labelling (registry-only agents shown as such, no fake chat, demo model labelled as demo).

### Final approval
- [ ] **Richard's explicit final approval** of the exact build and the exact listing/store copy to be published.

## What "publish" means here

Any of: Acquire.com (or similar) listing, Play Store / App Store submission,
public web hosting of the HTML build, or distribution of the APK outside
Richard's own devices. All are blocked until this gate passes in full.
