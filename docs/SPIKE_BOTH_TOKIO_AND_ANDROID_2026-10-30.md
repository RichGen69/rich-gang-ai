# Both tracks — Tokio sovereign kernel + Android Room/MediaPipe — 2026-10-30

At Richard's "Both" pick (after the 2026-10-30 audit that offered
"isolated Rust Tokio spike" vs "Android Room and MediaPipe setup").

## 1. Tokio sovereign kernel — VERIFIED IN THIS SESSION

- Location: `spikes/v5_007_tokio_sovereign_kernel/` (isolated crate,
  NOT a dependency of `rich_gang_ai_core`, NOT in `libdaemon.so`).
  Full record: `docs/SPIKE_V5_007_TOKIO_SOVEREIGN_KERNEL.md`.
- This session: added the missing demo binary
  (`src/main.rs`, declared in Cargo.toml but absent), then ran:
  - `cargo test --offline` — **4 passed, 0 failed**
    (routes all command kinds + clean shutdown, parked task
    cancelled on shutdown, channel-close paths).
  - `cargo run --offline` — demo prints the no-provider
    inference receipt and a clean shutdown outcome
    (`shutdown_clean: true, parked_task_completed: false`).
  - aarch64 target artifact already present in `target/`
    (built by the parallel track; see the v5_007 doc for its
    NDK r27 / API 24 build record). Not device-verified.
- Honest correction kept from the v5_007 design: inference
  returns `ERROR no_inference_provider` — no model, no GPU,
  no generated response. Memory/telemetry are in-memory
  receipts only. No latency or cost claim.

## 2. Android Room + MediaPipe — SPLIT INTO TWO PIECES

### 2a. Room — canonical piece is IN THE APP (parallel track, 09:09 CDT)
- `flutter_app/android/app/src/main/kotlin/com/richgang/ai/data/`
  (MessageEntity, ConversationFtsEntity with `contentEntity`
  triggers, SovereignDao, SovereignDatabase, SovereignMemoryStore,
  FtsQuery + FtsQueryTest) and Room 2.8.4 in the app's
  `build.gradle.kts`.
- Explicitly isolated: NOT wired into DreamCycleService, any
  chat view, or the Rust rusqlite store. Room vs Rust rusqlite
  as the single source of truth is still undecided.
- Not Gradle-built or device-verified in this session; the
  only Room test present is the JVM-only FtsQueryTest (no
  Android runtime, no Room round-trip test).

### 2b. MediaPipe — scaffold only, in spikes/
- `spikes/android_room_mediapipe/` (README, settings/build
  Gradle, `LocalInference.kt`, `ModelMissing.kt`).
- MediaPipe tasks-genai 0.10.14 declared, NOT resolved by a
  Gradle build, NOT added to the app. No `.task` model file
  exists; a missing model raises ModelMissingException and
  generates nothing. No GPU delegate is set.
- MediaPipe LLM Inference is maintenance-only per Google's
  own guide (new work goes to LiteRT-LM) — evaluate LiteRT-LM
  before committing to this API for production.
- This scaffold's Room files are SUPERSEDED by 2a; do not
  merge them on top of the in-app module.

## 3. What was NOT done
- No merge into `rich_gang_ai_core` or `native_bridge.dart`;
  the release gate was therefore not triggered by these spikes
  (it covers core/native_bridge changes).
- No TPU/GKE work, no HTML dashboard launch, no vault
  interaction, no model download, no device run.
- The screenshots Richard sent with "Both" (Room UI, Room
  scene photos, Rich Vision & Jarvis page) are design
  references only; they changed no code and no claim above.
  The Jarvis page's FFI return codes (1 success / 0 already
  initialized) also differ from the verified core's 0-success
  convention — that page is not the core's spec.

## Decisions — LOCKED 2026-10-30 (Richard, options widget)
1. **Rust rusqlite is the single conversation store.**
   Room stays parked and unwired; do not run both as live writers.
2. **On-device inference spike is LiteRT-LM, not MediaPipe,**
   and it comes only after the APK builds and is device-verified.
   No model file is chosen or downloaded yet.
3. Do NOT wire the in-app Room module into a chat view.
