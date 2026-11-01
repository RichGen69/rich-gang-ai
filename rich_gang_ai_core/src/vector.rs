//! Vector store abstraction for local memory.
//!
//! HONEST SCOPE (Richard's rule, 2026-10-21: no mock math): the vectors
//! used here are LEXICAL HASH VECTORS, not learned embeddings. There is
//! no embedding model in this build. Cosine similarity over these vectors
//! measures hashed token overlap — real arithmetic, lexical meaning only;
//! it does not measure semantic similarity, and nothing in the UI or docs
//! may present it as such. A real local embedding model can replace
//! `lexical_vector` behind this trait without FFI changes.
//!
//! Everything here is local only: nothing in this module talks to the
//! network. A persistent on-disk implementation slots in behind this
//! trait without FFI changes.

pub trait VectorStore: Send + Sync {
    fn upsert(&mut self, id: &str, vector: Vec<f32>, payload: String);
    /// Returns (id, payload, cosine score over lexical hash vectors),
    /// best first, at most `k`.
    fn query(&self, vector: &[f32], k: usize) -> Vec<(String, String, f32)>;
    fn len(&self) -> usize;
    fn is_empty(&self) -> bool {
        self.len() == 0
    }
}

/// Deterministic lexical hash vector for a text (64-dim hashed bag of
/// words, L2-normalised). NOT an embedding: no model, no semantics —
/// tokens are FNV-1a hashed into buckets, so two texts score as similar
/// only when they share tokens. That lexical ranking is what memory
/// recall actually provides today, labelled as what it is.
pub fn lexical_vector(text: &str) -> Vec<f32> {
    const DIM: usize = 64;
    let mut v = vec![0.0f32; DIM];
    for tok in text
        .to_lowercase()
        .split(|c: char| !c.is_alphanumeric())
        .filter(|s| !s.is_empty())
    {
        // FNV-1a hash of the token -> bucket + signed increment.
        let mut h: u64 = 0xcbf29ce484222325;
        for b in tok.as_bytes() {
            h ^= *b as u64;
            h = h.wrapping_mul(0x100000001b3);
        }
        let idx = (h % DIM as u64) as usize;
        v[idx] += if h & 0x8000_0000_0000_0000 != 0 { 1.0 } else { -1.0 };
    }
    let norm: f32 = v.iter().map(|x| x * x).sum::<f32>().sqrt();
    if norm > 0.0 {
        for x in &mut v {
            *x /= norm;
        }
    }
    v
}

fn cosine(a: &[f32], b: &[f32]) -> f32 {
    if a.len() != b.len() || a.is_empty() {
        return 0.0;
    }
    let dot: f32 = a.iter().zip(b).map(|(x, y)| x * y).sum();
    let na: f32 = a.iter().map(|x| x * x).sum::<f32>().sqrt();
    let nb: f32 = b.iter().map(|x| x * x).sum::<f32>().sqrt();
    if na == 0.0 || nb == 0.0 {
        return 0.0;
    }
    dot / (na * nb)
}

#[derive(Default)]
pub struct InMemoryVectorStore {
    rows: Vec<(String, Vec<f32>, String)>,
}

impl InMemoryVectorStore {
    pub fn new() -> Self {
        Self::default()
    }
}

impl VectorStore for InMemoryVectorStore {
    fn upsert(&mut self, id: &str, vector: Vec<f32>, payload: String) {
        if let Some(row) = self.rows.iter_mut().find(|r| r.0 == id) {
            row.1 = vector;
            row.2 = payload;
        } else {
            self.rows.push((id.to_string(), vector, payload));
        }
    }

    fn query(&self, vector: &[f32], k: usize) -> Vec<(String, String, f32)> {
        let mut scored: Vec<(String, String, f32)> = self
            .rows
            .iter()
            .map(|(id, emb, payload)| (id.clone(), payload.clone(), cosine(vector, emb)))
            .collect();
        scored.sort_by(|a, b| b.2.partial_cmp(&a.2).unwrap_or(std::cmp::Ordering::Equal));
        scored.truncate(k);
        scored
    }

    fn len(&self) -> usize {
        self.rows.len()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn lexical_vector_is_deterministic_and_ranks_token_overlap_first() {
        assert_eq!(lexical_vector("hello room"), lexical_vector("hello room"));
        let mut s = InMemoryVectorStore::new();
        s.upsert("m1", lexical_vector("the sedan left at night"), "sedan memory".into());
        s.upsert("m2", lexical_vector("quiet hours start at ten"), "quiet memory".into());
        let r = s.query(&lexical_vector("sedan at night"), 2);
        assert_eq!(r.len(), 2);
        // Shared tokens with m1 must not score below the unrelated text.
        assert!(r.iter().find(|x| x.0 == "m1").unwrap().2
            >= r.iter().find(|x| x.0 == "m2").unwrap().2);
    }

    #[test]
    fn query_ranks_nearest_first_and_upsert_replaces() {
        let mut s = InMemoryVectorStore::new();
        s.upsert("a", vec![1.0, 0.0], "alpha".to_string());
        s.upsert("b", vec![0.0, 1.0], "beta".to_string());
        s.upsert("a", vec![0.9, 0.1], "alpha2".to_string());
        assert_eq!(s.len(), 2);
        let r = s.query(&[1.0, 0.0], 2);
        assert_eq!(r[0].0, "a");
        assert_eq!(r[0].1, "alpha2");
    }
}
