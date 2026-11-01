//! Interrogation fact table.
//!
//! Deterministic: the witness testifies only from the facts listed here for
//! that witness. The model is given ONLY the facts its witness would know;
//! cross-referencing against the full table is the player's job, so this
//! module deliberately exposes per-witness views and a full view used by
//! the validator/tests — never hand the full view to a witness prompt.
//!
//! Scene content comes ONLY from the daemon config JSON under the
//! "facts" key. There is deliberately NO built-in scene: the previous
//! assistant-authored scene ("The Night Ledger") was removed on
//! 2026-10-21 under Richard's rule (no mock data — he supplies his own
//! scene data; see docs/SCENE_FORMAT.md). With no config facts, the
//! table is empty and interrogation mode shows its empty state.

use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct Fact {
    pub id: String,
    pub text: String,
    /// Whether the witness is permitted to lie about this fact in play.
    /// Lying is a game rule applied by the scene layer, not by the model.
    pub lie_permitted: bool,
    /// The deterministic false version this witness gives in play when
    /// `lie_permitted` is true. Absent = the witness tells the truth.
    #[serde(default)]
    pub lie_text: Option<String>,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct FactTable {
    /// witness name -> facts that witness knows
    witnesses: BTreeMap<String, Vec<Fact>>,
}

impl FactTable {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn from_config(value: &serde_json::Value) -> Self {
        match serde_json::from_value::<FactTable>(value.clone()) {
            Ok(t) => t,
            Err(e) => {
                // Logged loudly, never silently defaulted (principle 6).
                log::error!("facts: invalid fact table in config: {}", e);
                FactTable::default()
            }
        }
    }

    pub fn add_witness_fact(&mut self, witness: &str, fact: Fact) {
        self.witnesses
            .entry(witness.to_string())
            .or_default()
            .push(fact);
    }

    /// The ONLY view a witness prompt may receive.
    pub fn witness_facts(&self, witness: &str) -> Option<&[Fact]> {
        self.witnesses.get(witness).map(|v| v.as_slice())
    }

    /// Does `statement_id` belong to the set this witness actually knows?
    pub fn witness_knows(&self, witness: &str, fact_id: &str) -> bool {
        self.witness_facts(witness)
            .map(|facts| facts.iter().any(|f| f.id == fact_id))
            .unwrap_or(false)
    }

    pub fn witness_names(&self) -> Vec<&str> {
        self.witnesses.keys().map(|k| k.as_str()).collect()
    }

    /// The statement this witness actually gives for `fact_id` in play:
    /// the lie text when lying is permitted and a lie version exists,
    /// otherwise the true text. `None` when the witness does not know
    /// the fact at all — the UI must render that as "I don't know",
    /// never as an invented answer.
    pub fn statement_for(&self, witness: &str, fact_id: &str) -> Option<String> {
        let f = self
            .witness_facts(witness)?
            .iter()
            .find(|f| f.id == fact_id)?;
        if f.lie_permitted {
            if let Some(lie) = &f.lie_text {
                return Some(lie.clone());
            }
        }
        Some(f.text.clone())
    }

}

#[cfg(test)]
mod tests {
    use super::*;

    fn fact(id: &str) -> Fact {
        Fact {
            id: id.to_string(),
            text: format!("fact {id}"),
            lie_permitted: false,
            lie_text: None,
        }
    }

    #[test]
    fn statement_for_uses_lie_text_only_when_permitted() {
        // Minimal inline fixture (unit-test data only, not shipped
        // content): witness "a" may lie about fact x, witness "b" may not.
        let mut t = FactTable::new();
        t.add_witness_fact("a", Fact {
            id: "x".into(),
            text: "x is red".into(),
            lie_permitted: true,
            lie_text: Some("x is blue".into()),
        });
        t.add_witness_fact("b", Fact {
            id: "x".into(),
            text: "x is red".into(),
            lie_permitted: false,
            lie_text: Some("x is blue".into()),
        });
        // Permitted + lie text present -> the lie is what's said in play.
        assert_eq!(t.statement_for("a", "x").unwrap(), "x is blue");
        // Not permitted -> truth, even if a lie version exists.
        assert_eq!(t.statement_for("b", "x").unwrap(), "x is red");
        // Unknown fact / unknown witness -> None ("I don't know").
        assert!(t.statement_for("a", "nope").is_none());
        assert!(t.statement_for("nobody", "x").is_none());
        // The on-record truth is never mutated by play.
        let truth = t.witness_facts("a").unwrap().iter().find(|f| f.id == "x").unwrap();
        assert_eq!(truth.text, "x is red");
    }

    #[test]
    fn empty_by_default_no_builtin_scene() {
        // Regression guard for the 2026-10-21 removal: a fresh table —
        // and therefore a daemon started without config facts — has no
        // witnesses and no statements. No invented scene data.
        let t = FactTable::new();
        assert!(t.witness_names().is_empty());
        assert!(t.statement_for("anyone", "anything").is_none());
    }

    #[test]
    fn witness_sees_only_own_facts() {
        let mut t = FactTable::new();
        t.add_witness_fact("w1", fact("a"));
        t.add_witness_fact("w2", fact("b"));
        assert!(t.witness_knows("w1", "a"));
        assert!(!t.witness_knows("w1", "b"));
        assert!(t.witness_facts("nobody").is_none());
    }
}
