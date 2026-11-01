# INTEGRATION — v5 Tier 3 petgraph into rich_gang_ai_core

Date: 2026-10-22. Authorised by Richard: "Integrate petgraph into the core now" (after Spike 001 PASS).

## Changes
- `rich_gang_ai_core/Cargo.toml`: + `petgraph = "0.8.3"` (spike-verified version, pure Rust, no C deps)
- `rich_gang_ai_core/src/topology.rs` (new): `CausalTopology` — parking_lot RwLock<DiGraph<String,()>> + name index; add_entity (dedup), add_causal_link, causally_reaches (has_path_connecting), causal_order (toposort, cycle = explicit error), from_config (well-formed pairs only, malformed skipped)
- `rich_gang_ai_core/src/lib.rs`: `pub mod topology`; Daemon gains `topology` field, loaded from config key `"causal_links": [["cause","effect"],...]`; no key -> empty graph (config-only data rule, same as facts; shipped daemon_config.json has no causal_links, so the shipped graph is empty)
- `rich_gang_ai_core/src/ffi.rs`: two purely additive exports, ABI stays 2 — `rga_topology_state` ({nodes,edges,order} or causal_cycle_detected error doc) and `rga_topology_reaches` ({from,to,reaches}); cbindgen header regenerated with both
- `flutter_app/lib/core/native_bridge.dart`: bindings `topologyState()` + `topologyReaches(from,to)` following the existing ownership/free patterns
- No UI surface yet — no view calls these bindings. That is a separate step, not implied by this integration.

## Verification (this session, VM only — NOT device-verified)
- `cargo test`: **51 passed, 0 failed** (43 prior + 6 topology unit + 2 FFI topology)
- `flutter analyze`: **No issues found** (strict options unchanged)
- `flutter test`: **42 passed, 1 failed — failure is NOT from this integration.** `roster_asset_test.dart` expects Kelly title "The Vice City Wildcard" but shipped `characters.json` (and site/index.html) now say "The Neon Wildcard" — assets changed outside this task (parallel work); test/docs were not updated with it. Flagged to Richard; title is his roster decision, not changed here.
- `libdaemon.so` rebuilt release for aarch64-linux-android (NDK r27, API 24) and restaged to jniLibs/arm64-v8a: **SHA-256 9d47fa530faa2a392dbb766a9e8a1a62c8f91adc26a5fdd6aec4c89ee5c506a7**, 688K; all 4 LOAD segments Align 0x4000; **23 dynamic exports** = 19 rga_* (incl. new rga_topology_state, rga_topology_reaches) + 4 JNI, all prior exports present.

## Not proven / not done
- No device run (APK still blocked on other_tcp; publish gate still closed)
- No persistence for the topology; in-memory only, from config at daemon start
- No causal data shipped — Richard supplies "causal_links" when he wants a live graph, same as scene facts
