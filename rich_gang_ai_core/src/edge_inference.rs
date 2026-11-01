//! Edge (local) inference — the truthful version (Tier-10, 2026-10-21).
//!
//! There is NO local LLM runtime linked into this build: no GGML,
//! no ONNX, no WebGPU, and no memory-mapped weights. Earlier pasted
//! snippets "executed" local inference by formatting a canned
//! `[OFFLINE EDGE MODE] ...` string from the prompt length — that is
//! a simulated response, which Richard's standing rule (no mock
//! data) forbids presenting as functionality.
//!
//! So this module does the honest thing: it holds the configuration
//! a real runtime would need and returns an explicit error from
//! every entry point until a runtime is actually linked and a real
//! model file is present. Callers must surface that error; there is
//! no fallback text to show instead.

use std::path::PathBuf;

#[derive(Debug, Clone)]
pub struct EdgeConfig {
    pub model_path: PathBuf,
    pub max_context_tokens: usize,
    pub use_gpu_acceleration: bool,
}

pub struct EdgeInferenceEngine {
    config: EdgeConfig,
}

impl EdgeInferenceEngine {
    pub fn new(config: EdgeConfig) -> Self {
        Self { config }
    }

    /// Whether a local inference runtime is linked in this build.
    /// It is not — this is a compile-time fact today, not a probe.
    pub fn runtime_linked() -> bool {
        false
    }

    /// The explicit error every edge call returns in this build.
    fn unconfigured_error(&self) -> String {
        "edge_inference_unavailable: no local runtime (GGML/ONNX/WebGPU) \
         is linked in this build and no memory-mapped weights are loaded; \
         local edge inference is not configured"
            .to_string()
    }

    /// Validate configuration. Fails explicitly when the model file
    /// does not exist, and fails explicitly (even when a path does
    /// exist) because no runtime is linked to load it with.
    pub fn initialize(&self) -> Result<(), String> {
        if !self.config.model_path.exists() {
            return Err(format!(
                "edge_model_not_found: no model file at {:?}; edge inference is not configured",
                self.config.model_path
            ));
        }
        Err(self.unconfigured_error())
    }

    /// Run local inference. Always an explicit error in this build —
    /// never a formatted, simulated, or canned response.
    pub fn execute(&self, _agent_id: &str, _prompt: &str) -> Result<String, String> {
        Err(self.unconfigured_error())
    }

    pub fn config(&self) -> &EdgeConfig {
        &self.config
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn engine(path: &str) -> EdgeInferenceEngine {
        EdgeInferenceEngine::new(EdgeConfig {
            model_path: PathBuf::from(path),
            max_context_tokens: 2048,
            use_gpu_acceleration: false,
        })
    }

    #[test]
    fn missing_model_file_errors_explicitly() {
        let e = engine("/nonexistent/rich_gang_ai/model.gguf");
        let err = e.initialize().unwrap_err();
        assert!(err.contains("edge_model_not_found"), "got: {err}");
    }

    #[test]
    fn existing_path_still_errors_because_no_runtime_is_linked() {
        // Cargo.toml itself is a file that certainly exists; using it
        // as the path isolates the runtime check from the file check.
        let e = engine(env!("CARGO_MANIFEST_DIR"));
        let err = e.initialize().unwrap_err();
        assert!(
            err.contains("edge_inference_unavailable"),
            "got: {err}"
        );
        assert!(!EdgeInferenceEngine::runtime_linked());
    }

    #[test]
    fn execute_never_returns_a_fabricated_response() {
        let e = engine("/nonexistent/model.gguf");
        let err = e.execute("leo", "hello").unwrap_err();
        assert!(err.contains("edge_inference_unavailable"), "got: {err}");
        assert!(!err.contains("OFFLINE EDGE MODE"));
    }
}
