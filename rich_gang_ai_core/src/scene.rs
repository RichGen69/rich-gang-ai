//! Scene state machine + validator.
//!
//! The LLM proposes an `AffectFrame`; only this module may mutate `Scene`.
//! Every proposal is validated and clamped here. A schema or rule failure is
//! a `Reject` value the UI renders as an in-character deflection — never a
//! panic, never an exception across the FFI boundary.

use serde::{Deserialize, Serialize};

pub const INTENTS: [&str; 6] = [
    "question",
    "command",
    "threat",
    "joke",
    "confession",
    "silence",
];
pub const BEATS: [&str; 4] = ["advance", "stall", "escalate", "reveal"];
/// Light vocabulary is NOT enumerated in the master prompt. This set is a
/// conservative starting whitelist; extend it here (one place) when the
/// room's lighting design is finalised. Unknown values are rejected.
pub const LIGHTS: [&str; 5] = ["warm", "cold", "dim", "bright", "neutral"];

/// GBNF grammar (llama.cpp grammar format) for the AffectFrame JSON
/// shape, with the INTENTS / BEATS / LIGHTS whitelists baked in as
/// literal alternatives. This is the "GBNF affect schema" (build order
/// step 3): a local grammar-constrained engine can be held to exactly
/// this shape at generation time.
///
/// Layering is deliberate: the grammar enforces SHAPE and vocabulary
/// only. Numeric finiteness/range and the beat-transition rule cannot
/// be expressed in GBNF, so they stay where they already live — the
/// validator in `Scene::apply` (clamp finite out-of-range values,
/// reject non-finite ones, reject `advance` -> `reveal` skips). The
/// grammar never replaces the validator.
///
/// The hosted OpenAI-compatible endpoints (NVIDIA, Ollama /v1) still
/// have no verified grammar parameter — the Dart providers keep
/// throwing UnsupportedError for grammar requests there. This grammar
/// ships for the local-engine path and as the schema's canonical text.
pub const AFFECT_GRAMMAR_GBNF: &str = r#"root ::= "{" ws "\"say\"" ws ":" ws string "," ws "\"intent\"" ws ":" ws intent "," ws "\"affect\"" ws ":" ws affect "," ws "\"alignment\"" ws ":" ws number "," ws "\"beat\"" ws ":" ws beat "," ws "\"stage\"" ws ":" ws stage ws "}"
intent ::= "\"question\"" | "\"command\"" | "\"threat\"" | "\"joke\"" | "\"confession\"" | "\"silence\""
beat ::= "\"advance\"" | "\"stall\"" | "\"escalate\"" | "\"reveal\""
affect ::= "{" ws "\"valence\"" ws ":" ws number "," ws "\"arousal\"" ws ":" ws number "," ws "\"dominance\"" ws ":" ws number ws "}"
stage ::= "{" ws "\"light\"" ws ":" ws light "," ws "\"shake\"" ws ":" ws number ws "}"
light ::= "\"warm\"" | "\"cold\"" | "\"dim\"" | "\"bright\"" | "\"neutral\""
string ::= "\"" char* "\""
char ::= [^"\\] | "\\" (["\\/bfnrt] | "u" [0-9a-fA-F] [0-9a-fA-F] [0-9a-fA-F] [0-9a-fA-F])
number ::= "-"? ("0" | [1-9] [0-9]*) ("." [0-9]+)? ([eE] [+-]? [0-9]+)?
ws ::= [ \t\n]*
"#;

#[derive(Debug, Clone, Deserialize)]
pub struct AffectFrame {
    pub say: String,
    pub intent: String, // question|command|threat|joke|confession|silence
    pub affect: Affect,
    pub alignment: f32,
    pub beat: String, // advance|stall|escalate|reveal
    pub stage: Stage,
}

#[derive(Debug, Clone, Deserialize)]
pub struct Affect {
    pub valence: f32,
    pub arousal: f32,
    pub dominance: f32,
}

#[derive(Debug, Clone, Deserialize)]
pub struct Stage {
    pub light: String,
    pub shake: f32,
}

#[derive(Debug, Clone, Serialize)]
pub struct Delta {
    pub status: &'static str, // always "delta"
    pub say: String,
    pub intent: String,
    pub affect: AffectOut,
    pub alignment: f32,
    pub beat: String,
    pub stage: StageOut,
}

#[derive(Debug, Clone, Serialize)]
pub struct AffectOut {
    pub valence: f32,
    pub arousal: f32,
    pub dominance: f32,
}

#[derive(Debug, Clone, Serialize)]
pub struct StageOut {
    pub light: String,
    pub shake: f32,
}

#[derive(Debug, Clone, Serialize)]
pub struct Reject {
    pub status: &'static str, // always "reject"
    pub reason: String,
    pub detail: String,
}

impl Reject {
    fn new(reason: &str, detail: impl Into<String>) -> Self {
        Reject {
            status: "reject",
            reason: reason.to_string(),
            detail: detail.into(),
        }
    }
}

fn clamp_unit(v: f32) -> f32 {
    v.clamp(-1.0, 1.0)
}

fn finite(v: f32) -> bool {
    v.is_finite()
}

/// Point-in-time view of the scene, returned by `Scene::snapshot`.
/// `last_delta` is the most recent ACCEPTED frame (post-clamp), or
/// null before any frame has been accepted — the Performance Director
/// on the Dart side reads exactly this and invents nothing.
#[derive(Debug, Clone, Serialize)]
pub struct SceneSnapshot {
    pub accepted: u64,
    pub last_beat: Option<String>,
    pub escalated_since_advance: bool,
    pub last_delta: Option<Delta>,
}

#[derive(Debug, Default)]
pub struct Scene {
    /// Beat of the last accepted frame, if any.
    last_beat: Option<String>,
    /// True when an `escalate` has occurred since the last `advance`.
    escalated_since_advance: bool,
    /// Number of accepted frames.
    pub accepted: u64,
    /// The last accepted frame, post-clamp.
    last_delta: Option<Delta>,
}

impl Scene {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn apply(&mut self, f: AffectFrame) -> Result<Delta, Reject> {
        // 1. Whitelists.
        if !INTENTS.contains(&f.intent.as_str()) {
            return Err(Reject::new("unknown_intent", f.intent.clone()));
        }
        if !BEATS.contains(&f.beat.as_str()) {
            return Err(Reject::new("unknown_beat", f.beat.clone()));
        }
        if !LIGHTS.contains(&f.stage.light.as_str()) {
            return Err(Reject::new("unknown_light", f.stage.light.clone()));
        }

        // 2. Numeric sanity. Finite out-of-range values are clamped (per the
        // spec's validator sketch); non-finite values cannot be clamped and
        // are rejected loudly instead of silently defaulted.
        let nums = [
            f.affect.valence,
            f.affect.arousal,
            f.affect.dominance,
            f.alignment,
            f.stage.shake,
        ];
        if nums.iter().any(|v| !finite(*v)) {
            return Err(Reject::new(
                "non_finite_value",
                "affect, alignment and shake must be finite numbers",
            ));
        }

        // 3. Beat transitions may not skip states: `advance` -> `reveal`
        // without an intervening `escalate` is a reject.
        if self.last_beat.as_deref() == Some("advance")
            && f.beat == "reveal"
            && !self.escalated_since_advance
        {
            return Err(Reject::new(
                "beat_skip",
                "advance -> reveal requires an escalate first",
            ));
        }

        // 4. Accept: clamp, update state, return the Delta.
        let delta = Delta {
            status: "delta",
            say: f.say.clone(),
            intent: f.intent.clone(),
            affect: AffectOut {
                valence: clamp_unit(f.affect.valence),
                arousal: clamp_unit(f.affect.arousal),
                dominance: clamp_unit(f.affect.dominance),
            },
            alignment: clamp_unit(f.alignment),
            beat: f.beat.clone(),
            stage: StageOut {
                light: f.stage.light.clone(),
                shake: f.stage.shake.clamp(0.0, 1.0),
            },
        };

        match f.beat.as_str() {
            "advance" => self.escalated_since_advance = false,
            "escalate" => self.escalated_since_advance = true,
            _ => {}
        }
        self.last_beat = Some(f.beat.clone());
        self.accepted += 1;
        self.last_delta = Some(delta.clone());
        Ok(delta)
    }

    pub fn snapshot(&self) -> SceneSnapshot {
        SceneSnapshot {
            accepted: self.accepted,
            last_beat: self.last_beat.clone(),
            escalated_since_advance: self.escalated_since_advance,
            last_delta: self.last_delta.clone(),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn frame(beat: &str) -> AffectFrame {
        AffectFrame {
            say: "test line".to_string(),
            intent: "question".to_string(),
            affect: Affect {
                valence: 0.25,
                arousal: 0.0,
                dominance: -0.25,
            },
            alignment: 0.5,
            beat: beat.to_string(),
            stage: Stage {
                light: "warm".to_string(),
                shake: 0.1,
            },
        }
    }

    #[test]
    fn valid_frame_is_accepted_and_clamped() {
        let mut s = Scene::new();
        let mut f = frame("advance");
        f.affect.valence = 7.5;
        f.alignment = -42.0;
        let d = s.apply(f).expect("valid frame must apply");
        assert_eq!(d.affect.valence, 1.0);
        assert_eq!(d.alignment, -1.0);
        assert_eq!(s.accepted, 1);
    }

    #[test]
    fn unknown_intent_rejected() {
        let mut s = Scene::new();
        let mut f = frame("advance");
        f.intent = "sing".to_string();
        let r = s.apply(f).expect_err("unknown intent must reject");
        assert_eq!(r.reason, "unknown_intent");
    }

    #[test]
    fn advance_to_reveal_without_escalate_rejected() {
        let mut s = Scene::new();
        s.apply(frame("advance")).unwrap();
        let r = s.apply(frame("reveal")).expect_err("skip must reject");
        assert_eq!(r.reason, "beat_skip");
    }

    #[test]
    fn advance_escalate_reveal_accepted() {
        let mut s = Scene::new();
        s.apply(frame("advance")).unwrap();
        s.apply(frame("escalate")).unwrap();
        s.apply(frame("reveal")).expect("escalated reveal must apply");
        assert_eq!(s.accepted, 3);
    }

    #[test]
    fn snapshot_starts_empty_and_tracks_last_accepted_delta() {
        let mut s = Scene::new();
        let snap = s.snapshot();
        assert_eq!(snap.accepted, 0);
        assert!(snap.last_beat.is_none());
        assert!(snap.last_delta.is_none());

        s.apply(frame("escalate")).unwrap();
        let snap = s.snapshot();
        assert_eq!(snap.accepted, 1);
        assert_eq!(snap.last_beat.as_deref(), Some("escalate"));
        assert!(snap.escalated_since_advance);
        let d = snap.last_delta.expect("accepted frame must be retained");
        assert_eq!(d.beat, "escalate");
        assert_eq!(d.stage.light, "warm");
    }

    #[test]
    fn grammar_covers_every_field_and_whitelist_value() {
        for field in [
            "say",
            "intent",
            "affect",
            "valence",
            "arousal",
            "dominance",
            "alignment",
            "beat",
            "stage",
            "light",
            "shake",
        ] {
            assert!(
                AFFECT_GRAMMAR_GBNF.contains(field),
                "grammar missing field {field}"
            );
        }
        for v in INTENTS.iter().chain(BEATS.iter()).chain(LIGHTS.iter()) {
            assert!(
                AFFECT_GRAMMAR_GBNF.contains(v),
                "grammar missing whitelist value {v}"
            );
        }
        assert!(AFFECT_GRAMMAR_GBNF.starts_with("root ::="));
    }

    #[test]
    fn non_finite_rejected_not_defaulted() {
        let mut s = Scene::new();
        let mut f = frame("advance");
        f.affect.arousal = f32::NAN;
        let r = s.apply(f).expect_err("NaN must reject");
        assert_eq!(r.reason, "non_finite_value");
    }
}
