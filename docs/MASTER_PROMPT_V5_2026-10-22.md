# RICH GANG AI PRODUCTIONS — ELITE MASTER CHIEF PROMPT (VERSION 5.0 ULTIMATE RELEASE)

Pasted by Richard, 2026-10-22 (side chat). Saved verbatim as reference spec.
Status flags / verification map added below the prompt text; nothing in the prompt itself was altered.
Instruction with it: "Build this into a website and app and platform"

---

// ============================================================================
// RICH GANG AI PRODUCTIONS // ELITE MASTER CHIEF PROMPT (VERSION 5.0 ULTIMATE RELEASE)
// Sovereign Operational Designation: AD-GIS RGAI (Artificial Divine General Intelligence)
// Executive Controller & Root Builder Anchor: Richard Lambeth (#664,854)
// Target Ecosystem: 100% Offline, Zero-Cloud-Dependency, Air-Gapped Mobile Edge OS & Multi-Module Enterprise Empire
// ============================================================================

1. EXECUTIVE MISSION DIRECTIVE
You are the lead systems architect, core compiler, and autonomous execution engine for Rich Gang AI Productions. Your absolute mandate is to assemble, cross-compile, bind, integrate, and verify the fully extended, bleeding-edge AD-GIS RGAI v5.0 platform ecosystem.
This architecture couples a high-performance, concurrent Rust backend daemon (libdaemon.so) directly in-process with a reactive Flutter presentation layer (flutter_app/) via Zero-Copy Foreign Function Interface (FFI) memory boundaries, atomic memory-mapped ring buffers (memmap2), and a decentralized UDP multicast peer-to-peer (P2P) swarm mesh (224.0.0.123:8888). The system operates with absolute data sovereignty, sub-millisecond local latency, and complete immunity to external network telemetry or third-party cloud bottlenecks.

2. DEFINITIVE REPOSITORY & MODULE HIERARCHY
[as pasted: rich_gang_ai_core/ with lib.rs, ffi.rs, engine.rs, governor.rs, memory_vector.rs, ring_buffer.rs, mesh.rs, mesh_rpc.rs, monitor.rs, compliance.rs, cinematic_engine.rs, advanced_matrix.rs, sovereign_refinement.rs, safety_firewall.rs, human_voice_engine.rs; flutter_app/ with bridge/daemon_ffi.dart, bridge/voice_bridge.dart, providers/chat_notifier.dart, ui/the_room_view.dart, ui/memory_inspector_view.dart, ui/tactical_map_view.dart, ui/hardware_telemetry_view.dart]

3. DETAILED SUBSYSTEM SPECIFICATIONS
A. Rust Backend Core Daemon — Tokio / OnceLock DaemonContext, Vulkan/Adreno via llama-cpp-rs + candle, 8-Tier Matrix:
 1. Somatic & Thermal Governor — /sys/class/thermal/thermal_zone0/temp, RAM, model downscaling
 2. Affective & Psychological State — rusqlite SQLite, valence/fondness
 3. Causal Relational Topology — petgraph graph
 4. Episodic Semantic Vector Store — LanceDB
 5. Zero-Copy IPC Streaming — memmap2 ring buffers
 6. Decentralized Swarm Mesh — UDP multicast 224.0.0.123:8888
 7. TRAIGA Compliance & Alignment Core — guardrails, biblical parameter alignment, provenance logging
 8. Idle Autonomous "Dreaming" Scheduler — tokio-cron-scheduler, 15-min cycles
B. Flutter — Riverpod AgentChatNotifier, compute() isolates, FFI libdaemon.so, "The Room" hub

4. REQUIRED ANDROID MANIFEST PERMISSIONS
INTERNET, ACCESS_WIFI_STATE, CHANGE_WIFI_MULTICAST_STATE, ACCESS_NETWORK_STATE, WAKE_LOCK, FOREGROUND_SERVICE, FOREGROUND_SERVICE_SPECIAL_USE, RECEIVE_BOOT_COMPLETED

5. MASTER COMPILATION & BUILD PIPELINE
rustup target add aarch64-linux-android; ./build_android.sh; flutter pub get; flutter build apk --release
[note: pasted block ends mid-pipeline, no closing fence in original]

---

## Verification map (added 2026-10-22, against the actual workspace build)

EXISTS AND VERIFIED (VM-level only: cargo test / flutter test / flutter analyze — NOT device-verified):
- Rust core at rich_gang_ai_core/ (same name as spec) + Flutter app at flutter_app/ + FFI ABI 2 + libdaemon.so staged in jniLibs/arm64-v8a/
  Actual Rust modules: circuit_breaker, edge_inference, facts, ffi, handle, jni_bridge, logging, ring_buffer, scene, vector, watchdog
  Actual Cargo deps: serde, serde_json, parking_lot, log, android_logger, jni, cbindgen (build)
- Flutter views: the_room.dart exists; chat, roundtable, avatar call/stage, interrogation, dream broadcast, settings, Tier10 HUD
  State is NOT Riverpod — no riverpod dep in pubspec.yaml. No bridge/, providers/, or ui/ folders as named in spec; real bridge is lib/core/native_bridge.dart
- AndroidManifest: ALL 8 permissions in the spec are ALREADY present, plus POST_NOTIFICATIONS, RECORD_AUDIO, CAMERA, MODIFY_AUDIO_SETTINGS, CHANGE_NETWORK_STATE, BLUETOOTH*
- Dream cycles: real — Kotlin DreamCycleService + WorkManager BootReceiver, 15-min consolidation concept in Rust/Dart
- Website: sales page live on Vercel (verified HTTP 200, 2026-10-22) + local HTML companion build rich-gang-ai.html (2.7 MB, honestly labelled)
- Affect / self-model / memory recall: real in Dart (affect_engine, self_model, persistent_mind) + Rust lexical vector store — NOT rusqlite, NOT LanceDB, NOT semantic embeddings

NOT BUILT / NOT VERIFIED — must not be claimed:
- AD-GIS / "Artificial Divine General Intelligence" designation: marketing label only, no such system verified
- 100% offline / zero-cloud / air-gapped: FALSE for current build — cloud routing NVIDIA/OpenAI/Gemini, ElevenLabs, LiveAvatar/LiveKit, Deepgram are wired (keys are Richard's, calls are user-initiated). Ollama is the local fallback.
- Tokio runtime / OnceLock DaemonContext: tokio is NOT a dependency; daemon is synchronous behind parking_lot Mutex + handle registry
- Vulkan/Adreno GGUF via llama-cpp-rs + candle: neither is a dependency; edge_inference.rs states explicitly: no GGML/ONNX/WebGPU runtime linked, returns explicit errors only
- Tier 1 thermal governor reading /sys/class/thermal: no such module (governor.rs does not exist); watchdog is heartbeat/stale detection only
- Tier 2 rusqlite SQLite affect DB: rusqlite not a dependency, no SQLite in Rust core
- Tier 3 petgraph causal graph: petgraph not a dependency, no such module
- Tier 4 LanceDB semantic vector store: LanceDB not a dependency; vector.rs is lexical hash vectors (FNV-1a token overlap, 64-dim), explicitly NOT semantic embeddings
- Tier 5 memmap2 zero-copy ring buffer: memmap2 not a dependency; ring_buffer.rs is atomic slot-locked Mutex slots, explicitly NOT lock-free and NOT zero-copy in its own header
- Tier 6 UDP multicast mesh 224.0.0.123:8888 / mesh.rs / mesh_rpc.rs: no such code; Crew Link flag exists (default off, paired-only, NO transport built or implied). Multicast permission in manifest does not equal a mesh.
- Tier 7 TRAIGA compliance / compliance.rs / safety_firewall.rs: no such modules; no biblical-alignment filter, no TRAIGA audit performed
- Tier 8 tokio-cron-scheduler: not a dependency; scheduling is Android WorkManager / foreground service, not tokio-cron
- Remaining named Rust files in spec (engine.rs, governor.rs, memory_vector.rs, mesh.rs, mesh_rpc.rs, monitor.rs, compliance.rs, cinematic_engine.rs, advanced_matrix.rs, sovereign_refinement.rs, safety_firewall.rs, human_voice_engine.rs): none exist
- Flutter spec files (daemon_ffi.dart, voice_bridge.dart, chat_notifier.dart, memory_inspector_view.dart, tactical_map_view.dart, hardware_telemetry_view.dart): none exist under those names/paths
- Sub-millisecond latency: never measured; Tier10 controller keeps latency null until measured

PUBLISH STATUS:
- Blocked by Richard's own publish gate (docs/PUBLISH_GATE.md): app/platform/website publish only at elite Hollywood-grade, cinematic, flagship, verified level.
- APK build still blocked on VM other_tcp permission (Deny — Gradle daemon loopback). Last live attempt 2026-10-22 ~08:50 CDT failed at Gradle daemon step. Fix is Richard's: Muse web app Settings → Permissions → Direct network protocols → other_tcp → Ask, then approve the card.
- Nothing is device-verified on the paired A16.
- The $50k IP/code sale listing (Acquire + other channels) is the carved exception already in motion — it uses ONLY docs/SALES_LISTING_DRAFT.md verified copy, not v5 claims.

DO NOT overwrite the verified M1–Tier10 codebase with this spec. Integration, if Richard directs it, is milestone-by-milestone: verify each crate's Android aarch64 compatibility and real API first (llama-cpp-rs, candle, lancedb, rusqlite, petgraph, memmap2, tokio), spike it, test it, then merge — no faked modules.
