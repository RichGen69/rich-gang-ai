//! Causal relational topology (v5 Tier 3, integrated 2026-10-22 from
//! spike `spikes/v5_001_petgraph/` — see docs/SPIKE_V5_001_PETGRAPH.md
//! and docs/INTEGRATION_V5_PETGRAPH_2026-10-22.md).
//!
//! HONEST SCOPE: this is a directed graph of named entities and causal
//! links, nothing more. It does no reasoning of its own, generates no
//! conclusions, and holds no data that was not supplied in the daemon
//! config. An edge A -> B means "A is a cause / predecessor of B".
//! Multi-hop reachability and causal ordering are petgraph's real
//! algorithms (`has_path_connecting`, `toposort`); a cyclic graph
//! returns an explicit error from `causal_order`, never an invented
//! ordering.
//!
//! Data is config-only, like the fact table (Richard's decision,
//! 2026-10-21: he supplies his own data; nothing is built in). Config
//! shape:
//!   "causal_links": [["cause", "effect"], ...]
//! No "causal_links" key -> an empty graph and honest empty results.

use parking_lot::RwLock;
use petgraph::algo::{has_path_connecting, toposort};
use petgraph::graph::{DiGraph, NodeIndex};
use std::collections::HashMap;

pub struct CausalTopology {
    graph: RwLock<DiGraph<String, ()>>,
    index: RwLock<HashMap<String, NodeIndex>>,
}

impl Default for CausalTopology {
    fn default() -> Self {
        Self::new()
    }
}

impl CausalTopology {
    pub fn new() -> Self {
        Self {
            graph: RwLock::new(DiGraph::new()),
            index: RwLock::new(HashMap::new()),
        }
    }

    /// Build from the daemon config's "causal_links" array. Malformed
    /// entries (non-arrays, wrong arity, non-strings) are skipped, not
    /// guessed at — the same skip-don't-invent rule as persona parsing.
    pub fn from_config(v: &serde_json::Value) -> Self {
        let topo = Self::new();
        if let Some(links) = v.as_array() {
            for link in links {
                if let Some(pair) = link.as_array() {
                    if pair.len() == 2 {
                        if let (Some(from), Some(to)) =
                            (pair[0].as_str(), pair[1].as_str())
                        {
                            topo.add_causal_link(from, to);
                        }
                    }
                }
            }
        }
        topo
    }

    /// Add an entity by name; the same name always returns the
    /// existing node (no duplicate nodes for one entity).
    pub fn add_entity(&self, name: &str) -> NodeIndex {
        if let Some(idx) = self.index.read().get(name) {
            return *idx;
        }
        let idx = self.graph.write().add_node(name.to_string());
        self.index.write().insert(name.to_string(), idx);
        idx
    }

    fn node(&self, name: &str) -> Option<NodeIndex> {
        self.index.read().get(name).copied()
    }

    /// Add a causal link from -> to, creating entities if absent.
    pub fn add_causal_link(&self, from: &str, to: &str) {
        let a = self.add_entity(from);
        let b = self.add_entity(to);
        self.graph.write().add_edge(a, b, ());
    }

    pub fn node_count(&self) -> usize {
        self.graph.read().node_count()
    }

    pub fn edge_count(&self) -> usize {
        self.graph.read().edge_count()
    }

    pub fn is_empty(&self) -> bool {
        self.node_count() == 0
    }

    /// Is `to` reachable from `from` through any chain of causal
    /// links? Unknown names are false, never a guess.
    pub fn causally_reaches(&self, from: &str, to: &str) -> bool {
        let (Some(a), Some(b)) = (self.node(from), self.node(to)) else {
            return false;
        };
        let g = self.graph.read();
        has_path_connecting(&*g, a, b, None)
    }

    /// Causal ordering of all entities (causes before effects).
    /// Explicit error on a cycle — a cyclic causal graph has no
    /// valid ordering.
    pub fn causal_order(&self) -> Result<Vec<String>, String> {
        let g = self.graph.read();
        let order = toposort(&*g, None)
            .map_err(|cycle| format!("causal_cycle_detected_at_node_{:?}", cycle.node_id()))?;
        Ok(order.iter().map(|idx| g[*idx].clone()).collect())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sample() -> CausalTopology {
        let t = CausalTopology::new();
        t.add_causal_link("thermal_sensor", "governor");
        t.add_causal_link("governor", "model_downscale");
        t.add_causal_link("thermal_sensor", "thermal_alert");
        t
    }

    #[test]
    fn dedups_entities_by_name() {
        let t = CausalTopology::new();
        assert_eq!(t.add_entity("governor"), t.add_entity("governor"));
        assert_eq!(t.node_count(), 1);
    }

    #[test]
    fn multi_hop_reachability_is_real() {
        let t = sample();
        assert_eq!(t.node_count(), 4);
        assert_eq!(t.edge_count(), 3);
        assert!(t.causally_reaches("thermal_sensor", "model_downscale"));
        assert!(t.causally_reaches("thermal_sensor", "thermal_alert"));
        assert!(!t.causally_reaches("model_downscale", "thermal_sensor"));
        assert!(!t.causally_reaches("thermal_sensor", "no_such_entity"));
    }

    #[test]
    fn causal_order_respects_every_link() {
        let t = sample();
        let order = t.causal_order().expect("acyclic graph must order");
        let pos = |n: &str| order.iter().position(|x| x == n).unwrap();
        assert!(pos("thermal_sensor") < pos("governor"));
        assert!(pos("governor") < pos("model_downscale"));
        assert_eq!(order.len(), 4);
    }

    #[test]
    fn cycle_is_rejected_explicitly() {
        let t = CausalTopology::new();
        t.add_causal_link("a", "b");
        t.add_causal_link("b", "a");
        let err = t.causal_order().expect_err("cycle must error");
        assert!(err.contains("causal_cycle_detected"), "got: {err}");
    }

    #[test]
    fn from_config_loads_only_well_formed_links() {
        let v = serde_json::json!([
            ["sensor", "governor"],
            ["governor", "downscale"],
            ["broken"],
            [1, 2],
            "not_a_pair"
        ]);
        let t = CausalTopology::from_config(&v);
        assert_eq!(t.node_count(), 3);
        assert_eq!(t.edge_count(), 2);
        assert!(t.causally_reaches("sensor", "downscale"));
    }

    #[test]
    fn empty_by_default_no_builtin_links() {
        // Regression guard, same pattern as the fact table: no config
        // data means an empty graph, never built-in invented links.
        let t = CausalTopology::new();
        assert!(t.is_empty());
        assert_eq!(t.causal_order().unwrap(), Vec::<String>::new());
    }
}
