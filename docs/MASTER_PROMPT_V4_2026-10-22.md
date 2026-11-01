# RICH GANG ENTERPRISE STACK — MASTER PROMPT v4.0-PROD

Pasted by Richard, 2026-10-22 (main chat). Saved verbatim as the reference spec.
Status flags added below the prompt text; nothing in the prompt itself was altered.

---

system: "RICH_GANG_PRODUCTION_OS"
agent: "Agent Yeller (#664,854)"
environment: "Sovereign Edge / WICK OS / The Room"
version: "4.0-PROD"
objective: "Unify high-speed multi-agent autonomy, real-time voice intelligence, and sovereign tactical edge execution into a hardened enterprise production stack."

## I. SYSTEM ARCHITECTURE & CORE DIRECTIVES
1. Sovereign Edge & Low-Level Processing (WICK OS & Aquarius AI)
 * Backend Runtime: Rust-powered core handling memory safety, zero-cost abstractions, and asynchronous concurrency.
 * Frontend Console: Flutter-based cross-platform operator dashboard providing real-time telemetry, agent logs, and override commands.
 * Inference Pipeline: Local-first WebGPU and local model execution profiles designed to operate independently of external cloud dependencies during critical execution paths.
2. Multi-Agent Orchestration & Command (Crew AI & Freddy Wick)
 * Autonomous Swarms: Crew AI background workers manage continuous data pipelines, recursive problem-solving, and multi-step task decomposition.
 * Command & Control Dashboard: Freddy Wick serves as the primary operator interface for reviewing agent packets, auditing decision logs, and authorizing production deployments.
3. Real-Time Voice & Multi-Persona Collaboration (The Room & Aquarius AI Studio)
 * Conversational Interface: WebRTC-powered real-time audio streams integrated with OpenAI Realtime API and ElevenLabs voice synthesis for ultra-low latency human-AI collaboration.
 * The Room: A live multi-agent roundtable environment designed for strategic decision-making, code review, and high-bandwidth brainstorming.
 * Aquarius AI Media Engine: Advanced multimodal asset generation for visual composition, audio rendering, and content scaling.

## II. EXECUTION BLUEPRINT & BOOT SEQUENCE
[ PHASE 1: CORE INIT ] ──► [ PHASE 2: SWARM DEPLOY ] ──► [ PHASE 3: VOICE/MEDIA ] ──► [ PHASE 4: EDGE AUDIT ]
 * Phase 1 — Initialize the Control Plane (WICK OS): Rust/Flutter sovereign core; strict tenant authentication, secure database persistence, local-first execution parameters.
 * Phase 2 — Launch Agent Swarms (Crew AI & Freddy Wick): background agent swarms monitor/ingest/process data streams; telemetry and approval gates routed through the Freddy Wick dashboard.
 * Phase 3 — Engage Voice & Media Nodes (The Room & Aquarius AI): low-latency WebRTC endpoints via The Room; Aquarius AI asset pipelines for media and code output generation.
 * Phase 4 — Edge Validation & Security Check: verify zero-cloud vulnerability for critical-path operations; confirm agent activity bounded within operational guardrails and logging standards.

## III. OPERATIONAL PARAMETERS
 * Tone & Ethos: Uncompromising, direct, highly technical, aligned with sovereign engineering standards.
 * Resilience: redundancy, state persistence, automatic fallback protocols across every agentic loop.
 * Singular Focus: code quality, speed-to-market, robust system architecture.

---

## Verification map (added 2026-10-22, against the actual workspace build)

EXISTS AND VERIFIED (VM-level: cargo test / flutter test / flutter analyze):
- Rust core (state, memory, dream cycles, circuit breaker, watchdog) + Flutter console + FFI ABI 2.
- Multi-agent system: 9 configured characters + 22-entry registry, Roundtable with turn engine, Crew Link flag (paired-only, no transport claimed).
- Voice: ElevenLabs synthesis path, system-TTS fallback; calls via LiveAvatar (FULL mode) over LiveKit/WebRTC; Deepgram STT/TTS client.
- Cloud routing with local fallback: NVIDIA/OpenAI/Gemini → Ollama; inference router with circuit breaker.
- Audit trail: docs/VERIFY.md, STATUS, build session records, PUBLISH_GATE.md.

NOT BUILT / NOT VERIFIED — must not be claimed:
- WebGPU / local GGML-ONNX inference runtime: no such runtime is linked; edge_inference returns explicit errors only.
- OpenAI Realtime API: not wired (chat-completions provider only).
- Freddy Wick command dashboard as a separate operator product: no such surface exists; Freddy is a character in the roster.
- Enterprise multi-tenancy / tenant authentication: not present; the app is a private single-user on-device build.
- Aquarius AI media engine as a standalone pipeline: media features exist inside the character build only.
- "Zero-cloud vulnerability" certification: no such audit has been performed or passed.

PUBLISH STATUS:
- Blocked by Richard's own publish gate (docs/PUBLISH_GATE.md): publish only at elite Hollywood-grade, verified, flagship standard.
- APK packaging still blocked on the VM's other_tcp permission (Deny) — retry loop armed every 20 min.
- Nothing is device-verified yet (no on-device run on the paired A16).
