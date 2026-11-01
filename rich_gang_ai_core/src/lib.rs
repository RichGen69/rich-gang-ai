pub mod circuit_breaker;
pub mod edge_inference;
pub mod facts;
pub mod ffi;
pub mod handle;
pub mod intent_queue;
#[cfg(target_os = "android")]
pub mod jni_bridge;
pub mod logging;
pub mod reclaim;
pub mod ring_buffer;
pub mod ring_ipc;
pub mod scene;
pub mod spawn_budget;
pub mod store;
pub mod topology;
pub mod vector;
pub mod watchdog;

use parking_lot::Mutex;
use std::sync::atomic::{AtomicU64, Ordering};

/// Default persona roster: the personas evidenced in THE ROOM UI material
/// supplied with the build (Leo, Capricorn, Aquarius). The master prompt
/// says seven personas but names none; the remaining four must be supplied
/// by the user and can be set today via the "personas" array in the daemon
/// config JSON — no code change needed.
pub const DEFAULT_PERSONAS: [&str; 3] = ["leo", "capricorn", "aquarius"];

/// Live daemon state. Owned by Rust behind an opaque FFI handle; Dart and
/// Kotlin only ever hold the pointer. See handle.rs for the live registry
/// that makes use-after-free / double-free impossible.
pub struct Daemon {
    config: serde_json::Value,
    personas: Vec<String>,
    ticks: AtomicU64,
    scene: Mutex<scene::Scene>,
    facts: facts::FactTable,
    /// Causal relational topology (v5 Tier 3, petgraph). Config-only
    /// data, empty when the config has no "causal_links" key.
    topology: topology::CausalTopology,
    /// Persistent key-value store (v5 Tier 2, rusqlite/SQLite).
    /// File-backed when the config names a "store_path", in-memory
    /// for the session otherwise — and the store state surface says
    /// which, so session storage is never mistaken for durable.
    store: store::SqlStore,
    /// Memory-mapped SPSC ring (v5 Tier 5, memmap2). Enabled only
    /// when the config names a "ring_path" (with "ring_capacity");
    /// disabled otherwise and the ring state surface says so.
    ring: ring_ipc::RingIpc,
    /// Bounded agent-task budget (Execution Matrix reality,
    /// 2026-10-31: max 3 concurrent tasks, explicit exhaustion).
    spawn: Mutex<spawn_budget::SpawnBudget>,
    /// Bounded FIFO intent queue (Execution Matrix reality,
    /// 2026-10-31: ingestion stage only; arbitration lives in the
    /// Roundtable + Danny chain on the Dart side).
    intents: Mutex<intent_queue::IntentQueue>,
    memory: Mutex<vector::InMemoryVectorStore>,
    /// Most recent remembered texts, newest last, capped at 50.
    recent: Mutex<Vec<String>>,
    /// Text-only dream broadcasts produced so far, in order.
    broadcasts: Mutex<Vec<String>>,
}

impl Daemon {
    pub fn new(config_json: &str) -> Result<Self, String> {
        let config: serde_json::Value = if config_json.trim().is_empty() {
            serde_json::json!({})
        } else {
            serde_json::from_str(config_json)
                .map_err(|e| format!("invalid_config_json: {e}"))?
        };

        let personas: Vec<String> = config
            .get("personas")
            .and_then(|v| v.as_array())
            .map(|arr| {
                arr.iter()
                    .filter_map(|v| v.as_str().map(|s| s.to_lowercase()))
                    .collect::<Vec<_>>()
            })
            .filter(|v: &Vec<String>| !v.is_empty())
            .unwrap_or_else(|| DEFAULT_PERSONAS.iter().map(|s| s.to_string()).collect());

        // Scene data is config-only (Richard's decision, 2026-10-21:
        // he supplies his own scene; no built-in invented scene). No
        // "facts" key -> an empty table and an honest empty state in
        // the interrogation UI.
        let facts = match config.get("facts") {
            Some(v) => facts::FactTable::from_config(v),
            None => facts::FactTable::new(),
        };

        // Causal topology is config-only, same rule as facts: no
        // "causal_links" key -> an empty graph, never built-in links.
        let topology = match config.get("causal_links") {
            Some(v) => topology::CausalTopology::from_config(v),
            None => topology::CausalTopology::new(),
        };

        // Persistent store: a config "store_path" that cannot be
        // opened fails daemon start outright (explicit error) rather
        // than silently degrading to in-memory storage.
        let store = store::SqlStore::from_config(&config)?;

        // Memory-mapped ring: a config "ring_path" that cannot be
        // opened (or a missing/invalid "ring_capacity" beside it)
        // fails daemon start outright — same posture as the store,
        // and no capacity is ever defaulted.
        let ring = ring_ipc::RingIpc::from_config(&config)?;

        // Intent queue capacity is caller policy from config
        // ("intent_queue_capacity"); the default 64 is a default,
        // documented as such, never a measured figure. An explicit
        // zero is an explicit daemon-start error, not a silent queue
        // that can never accept anything.
        let intent_capacity = match config.get("intent_queue_capacity") {
            Some(v) => v.as_u64().map(|n| n as usize).ok_or_else(|| {
                "invalid intent_queue_capacity: must be a positive integer"
                    .to_string()
            })?,
            None => 64,
        };
        let intents = intent_queue::IntentQueue::new(intent_capacity)?;

        Ok(Daemon {
            config,
            personas,
            ticks: AtomicU64::new(0),
            scene: Mutex::new(scene::Scene::new()),
            facts,
            topology,
            store,
            ring,
            spawn: Mutex::new(spawn_budget::SpawnBudget::new()),
            intents: Mutex::new(intents),
            memory: Mutex::new(vector::InMemoryVectorStore::new()),
            recent: Mutex::new(Vec::new()),
            broadcasts: Mutex::new(Vec::new()),
        })
    }

    pub fn knows_persona(&self, persona: &str) -> bool {
        self.personas.iter().any(|p| p == &persona.to_lowercase())
    }

    pub fn tick(&self) -> u64 {
        self.ticks.fetch_add(1, Ordering::SeqCst) + 1
    }

    pub fn config(&self) -> &serde_json::Value {
        &self.config
    }

    pub fn facts(&self) -> &facts::FactTable {
        &self.facts
    }

    pub fn topology(&self) -> &topology::CausalTopology {
        &self.topology
    }

    pub fn store(&self) -> &store::SqlStore {
        &self.store
    }

    pub fn ring(&self) -> &ring_ipc::RingIpc {
        &self.ring
    }

    /// Acquire one spawn-budget slot (0..2). Explicit error past 3.
    pub fn spawn_acquire(&self) -> Result<usize, String> {
        self.spawn.lock().acquire()
    }

    /// Release a spawn-budget slot. Explicit error when not held.
    pub fn spawn_release(&self, slot: usize) -> Result<(), String> {
        self.spawn.lock().release(slot)
    }

    /// (max, held, free slots) — real budget state, nothing estimated.
    pub fn spawn_state(&self) -> (usize, usize, Vec<usize>) {
        let b = self.spawn.lock();
        (
            spawn_budget::MAX_CONCURRENT_TASKS,
            b.held_count(),
            b.free_slots(),
        )
    }

    /// Enqueue one intent. Explicit error when the queue is full.
    pub fn intent_enqueue(&self, intent: String) -> Result<usize, String> {
        self.intents.lock().enqueue(intent)
    }

    /// Dequeue the oldest intent, or None when empty.
    pub fn intent_dequeue(&self) -> Option<String> {
        self.intents.lock().dequeue()
    }

    /// (depth, capacity, full) — real queue state.
    pub fn intent_state(&self) -> (usize, usize, bool) {
        let q = self.intents.lock();
        (q.len(), q.capacity(), q.is_full())
    }

    pub fn personas(&self) -> &[String] {
        &self.personas
    }

    pub fn tick_count(&self) -> u64 {
        self.ticks.load(Ordering::SeqCst)
    }

    /// Store one memory locally: lexical hash vector in the vector store
    /// plus the raw text in the recent list. Returns the memory count.
    pub fn remember(&self, id: &str, text: &str) -> usize {
        use vector::VectorStore;
        let mut store = self.memory.lock();
        store.upsert(id, vector::lexical_vector(text), text.to_string());
        let n = store.len();
        drop(store);
        let mut recent = self.recent.lock();
        recent.push(text.to_string());
        if recent.len() > 50 {
            let excess = recent.len() - 50;
            recent.drain(0..excess);
        }
        n
    }

    /// Recall the `k` memories with the highest lexical (token-overlap)
    /// score against `query`. Returns (id, payload, cosine score over
    /// lexical hash vectors), best first. This is not semantic recall —
    /// see vector.rs for the honest scope.
    pub fn recall(&self, query: &str, k: usize) -> Vec<(String, String, f32)> {
        use vector::VectorStore;
        let store = self.memory.lock();
        store.query(&vector::lexical_vector(query), k.max(1).min(20))
    }

    pub fn memory_len(&self) -> usize {
        use vector::VectorStore;
        self.memory.lock().len()
    }

    /// Produce and store a text-only dream broadcast (Milestone 10).
    /// FACTUAL ONLY (Richard's rule, 2026-10-21: no mock data): every
    /// number and quoted string in the output is real daemon state —
    /// the tick count, the stored-memory count, and the actual stored
    /// texts. No invented narration, no atmospheric filler. Any richer
    /// broadcast prose must come from a real routed inference call on
    /// the Dart side, not from templates here.
    pub fn dream_broadcast(&self) -> (u64, String) {
        let tick = self.tick();
        let recent = self.recent.lock();
        let text = if recent.is_empty() {
            format!("Dream cycle {tick}. Memories stored: 0. Nothing to consolidate.")
        } else {
            let last: Vec<&String> = recent.iter().rev().take(3).collect();
            let joined = last
                .iter()
                .rev()
                .map(|s| s.as_str())
                .collect::<Vec<_>>()
                .join(" / ");
            format!(
                "Dream cycle {tick}. Memories stored: {}. Most recent entries: {joined}",
                recent.len()
            )
        };
        drop(recent);
        self.broadcasts.lock().push(text.clone());
        (tick, text)
    }

    pub fn broadcasts(&self) -> Vec<String> {
        self.broadcasts.lock().clone()
    }
}
