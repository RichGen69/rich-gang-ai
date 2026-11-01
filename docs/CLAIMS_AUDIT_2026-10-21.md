# Claims audit — prospectus vs. verified build state

Date: 2026-10-21 (night pass, on Richard's "go do all").
Rule: PUBLISH_GATE.md — every prospectus claim is verified with evidence
or removed from listing/store copy. Valuation figures are Richard's
asking position, never appraised value.

Source audited: docs/PROSPECTUS_RICHARD_SUPPLIED.md (Richard-supplied;
the supplied file itself is left untouched — this audit governs what
may be copied into any listing).

| # | Claim in prospectus | Verdict | Evidence / required change |
|---|---|---|---|
| 1 | "Failover Latency: Sub-5 milliseconds via active Rust Circuit Breakers" | UNVERIFIED — strike or reword | circuit_breaker.rs exists and is unit-tested, but no failover latency benchmark has ever been run. No number may be published until a benchmark on device/VM produces it. |
| 2 | "Memory-mapped local Edge AI runtime with WebGPU/ONNX/GGML hardware acceleration" | NOT IN BUILD — remove | No GGML/ONNX/WebGPU weights or runtime ship in this build. Local recall is FNV-1a lexical hash vectors (labelled as such in code). Claim describes an architecture that does not exist here. |
| 3 | "Deepgram Nova-2 (STT)" | WRONG MODEL — correct to Nova-3 | The built Deepgram client uses model=nova-3 (STT) + Aura (TTS), verified in BUILD_SESSION_2026-10-21d. |
| 4 | "Cryptographic JWT middleware and age-assurance challenges securing 21+ restricted agent nodes" | MISLEADING — reword | JWT exists only as LiveKit access-token minting. The 21+ gate is confirmation-only (tap "I am 21+") — per PUBLISH_GATE that is NOT verified age assurance. Copy must not imply verified age checks. |
| 5 | "22-agent context matrix" / roster-scale claims | MISLEADING as marketed roster | 22 registry entries exist; only 9 are fully configured (portrait+voice+affect). Registry-only agents may not be advertised as finished characters (gate roster item). |
| 6 | "Tier-10 Enterprise Infrastructure (Zero-Trust / High-Availability)" + availability implications | UNVERIFIED — remove availability language | No availability measurement exists. "High-Availability" is an aspiration, not a measured property of a single-device app. |
| 7 | "$100,000+ / 6–9 months R&D replacement cost" | ASKING POSITION ONLY | May appear only framed as Richard's own estimate/asking position, never as an appraisal. |

Verified-safe statements available for copy (evidence in build docs):
- Rust-owned state with validated FFI (ABI 2), 43/43 cargo tests,
  43/43 flutter tests, flutter analyze clean (2026-10-21).
- libdaemon.so: 16 KB LOAD alignment, 21 native exports, symbol-verified
  against Dart/Kotlin lookups.
- On-device-first design; cloud providers (NVIDIA/OpenAI/Gemini) are
  optional enhancements behind explicit keys; dream cycles every 15 min.
- Restraint layer: trust dial, quiet hours, kill switch, no autoplay,
  no re-engagement notifications.

Still required before ANY of this copy is used: the gate's remaining
items (APK, device verification, live provider calls, real age
assurance, roster decisions, Richard's final approval of exact copy).
