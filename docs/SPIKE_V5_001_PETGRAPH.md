# SPIKE V5-001 — petgraph (v5 Tier 3: Causal Relational Topology)

Date: 2026-10-22. Authorised by Richard: "Start the v5 verification spikes, one crate at a time."
Location: `spikes/v5_001_petgraph/` — isolated crate, NOT a dependency of `rich_gang_ai_core`.

## Verified before coding
- docs.rs: petgraph latest 0.8.3 (search result, docs.rs/crate/petgraph/0.8.3). Supports Rust 1.64+; this VM has rustc 1.99.1.
- APIs used, all real in 0.8.3: `petgraph::graph::{DiGraph, NodeIndex}`, `petgraph::algo::{toposort, has_path_connecting}`, `Graph::add_node / add_edge / node_count / edge_count`.
- Cargo.lock confirms: petgraph 0.8.3 from crates.io, 14 packages locked total (petgraph deps: fixedbitset, indexmap, hashbrown, foldhash, equivalent — all pure Rust, no C libraries).

## What was built in the spike
`CausalTopology`: `RwLock<DiGraph<String, ()>>` + name→NodeIndex map.
- Edge A -> B = "A is a cause/predecessor of B"
- `add_entity` (dedup by name), `add_causal_link`, `causally_reaches` (multi-hop via `has_path_connecting`, unknown names = false), `causal_order` (via `toposort`, cycle = explicit error string, never an invented order)

## Results — real, reproduced in this session
- Host: `cargo test` — **4 passed, 0 failed**
  - dedups_entities_by_name, multi_hop_reachability_is_real, causal_order_respects_every_link, cycle_is_rejected_explicitly
- Android target: `cargo check --target aarch64-linux-android` — **pass** (NDK r27, API 24 clang, same env as build_android.sh)
- Android target: `cargo build --target aarch64-linux-android` — **pass**; produced `libpetgraph-*.rlib` (4.9 MB debug) and spike rlib (1.9 MB debug). Debug sizes only — no release/size claim made.

## Verdict
**PASS — spike level only.**
petgraph is viable for Tier 3: pure Rust, cross-compiles cleanly, graph semantics needed by the spec are real and test-proven.

## What this does NOT prove
- Not integrated into `rich_gang_ai_core`, not exposed over FFI, not in `libdaemon.so`
- Not device-verified (nothing ran on the A16 — no APK exists yet, other_tcp blocker unchanged)
- No persistence, no scale/performance measurement, no latency claim
- Integration is a separate milestone requiring Richard's go-ahead: add petgraph to the core Cargo.toml, add a topology module behind the existing handle/FFI patterns, re-run cargo 43+new / flutter suites, rebuild + restage libdaemon.so

## Next spike in queue
002 — rusqlite (bundled SQLite, Tier 2). Expect a harder spike: it compiles C (SQLite) and will need the Android clang/CC env throughout, not just the linker.
