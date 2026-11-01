#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

/**
 * Latency above this is treated as a failure signal by
 * [`CircuitBreaker::record_latency`]. The 250 ms threshold is the
 * value Richard supplied in the Tier-10 specification.
 */
#define LATENCY_FAILURE_THRESHOLD_MS 250

#define ABI_VERSION 2

/**
 * Maximum concurrent agent tasks. The myth's N ≤ 3, as policy.
 */
#define MAX_CONCURRENT_TASKS 3

/**
 * Bump on ANY signature change in this file. Currently 2
 * (v2 added rga_personas / rga_remember / rga_recall /
 * rga_witness_facts / rga_witness_statement / rga_dream_broadcast;
 * rga_witnesses, rga_scene_state and rga_affect_grammar were added
 * later as purely additive exports; rga_topology_state and
 * rga_topology_reaches were added 2026-10-22 as purely additive
 * exports, ABI stays 2; rga_store_state / rga_store_put /
 * rga_store_get / rga_store_delete were added 2026-10-23 as purely
 * additive exports, ABI stays 2; rga_ring_state / rga_ring_send /
 * rga_ring_recv were added 2026-10-23 as purely additive exports,
 * ABI stays 2; rga_spawn_state / rga_spawn_acquire /
 * rga_spawn_release / rga_intent_state / rga_intent_enqueue /
 * rga_intent_dequeue / rga_reclaim_report / rga_reclaim_delete /
 * rga_reclaim_trim were added 2026-10-31 as purely additive
 * exports (Execution Matrix reality), ABI stays 2).
 */
uint32_t rga_abi_version(void);

/**
 * Static version string. Do NOT free.
 */
const char *rga_version(void);

void *rga_daemon_start(const char *config_json);

/**
 * Idempotent. No-op on an invalid or already-stopped handle.
 */
void rga_daemon_stop(void *h);

char *rga_agent_query(void *h, const char *persona, const char *input);

/**
 * Returns 0 on an invalid handle.
 */
uint64_t rga_dream_cycle_tick(void *h);

/**
 * Applies one AffectFrame proposal to the scene. Always returns a JSON
 * document: a Delta on success, a Reject on any validation failure.
 */
char *rga_scene_apply(void *h, const char *proposal_json);

/**
 * Current scene state as a JSON snapshot: accepted-frame count, last
 * beat, and the last ACCEPTED Delta (post-clamp), or
 * `"last_delta": null` before any frame has been accepted. This is
 * the Performance Director's only input — real state, read live.
 */
char *rga_scene_state(void *h);

/**
 * The GBNF grammar for the AffectFrame schema (build order step 3),
 * as plain text (NOT JSON). Ownership follows the file contract: the
 * returned `*mut c_char` must be freed once via `rga_string_free`.
 */
char *rga_affect_grammar(void);

/**
 * Persona roster as `{"personas":["leo", ...]}`.
 */
char *rga_personas(void *h);

/**
 * Store one memory locally. `{"ok":true,"count":N}` or an error doc.
 */
char *rga_remember(void *h, const char *id, const char *text);

/**
 * Recall memories similar to `query`. `{"results":[{id,payload,score}]}`
 */
char *rga_recall(void *h, const char *query, uint32_t k);

/**
 * Facts a witness knows: `{"witness":..., "facts":[{id,text,lie_permitted}]}`
 * The lie text and the truth behind a permitted lie are NOT included —
 * a witness prompt must never receive them from this function beyond
 * what `rga_witness_statement` gives in play; cross-referencing data
 * stays player-side. Unknown witness -> structured error.
 */
char *rga_witness_facts(void *h, const char *witness);

/**
 * List the witness names in the loaded fact table:
 * `{"witnesses": ["...", ...]}`. Empty when no scene is loaded — the
 * UI renders its empty state from this, never from hardcoded names.
 * (Added 2026-10-21 when the built-in scene was removed; additive
 * export, ABI stays 2.)
 */
char *rga_witnesses(void *h);

/**
 * The in-play statement for one fact: `{"statement": "..."}` — the lie
 * version when lying is permitted — or `{"error":"unknown_fact"}` when
 * the witness does not know it (UI renders "I don't know").
 */
char *rga_witness_statement(void *h, const char *witness, const char *fact_id);

/**
 * Produce a text-only dream broadcast. Advances the tick counter,
 * stores the broadcast, returns `{"ok":true,"tick":N,"broadcast":"..."}`.
 */
char *rga_dream_broadcast(void *h);

/**
 * Causal topology snapshot (v5 Tier 3, petgraph; added 2026-10-22,
 * additive export, ABI stays 2):
 * `{"nodes":N,"edges":M,"order":[...]}` — order is the causal
 * ordering (causes before effects). Empty graph (no "causal_links"
 * in the daemon config) returns zero counts and an empty order —
 * an honest empty state, not built-in data. A cyclic graph returns
 * `{"error":"causal_cycle_detected","detail":...,"nodes":N,"edges":M}`.
 */
char *rga_topology_state(void *h);

/**
 * Multi-hop causal reachability (v5 Tier 3): does `from` causally
 * reach `to` through any chain of config-supplied links?
 * `{"from":...,"to":...,"reaches":bool}` — unknown names are
 * `reaches:false`, never a guess.
 */
char *rga_topology_reaches(void *h, const char *from, const char *to);

/**
 * Persistent store snapshot (v5 Tier 2, rusqlite; added 2026-10-23,
 * additive export, ABI stays 2):
 * `{"persistent":bool,"journal_mode":...,"entries":N,"sqlite_version":...}`.
 * `persistent` is false when the daemon config named no
 * "store_path" — the store is then in-memory for this session only,
 * and this document says so plainly. A database failure returns
 * `{"error":"store_error","detail":...}`.
 */
char *rga_store_state(void *h);

/**
 * Store one key/value pair (v5 Tier 2): `{"ok":true,"key":...}`.
 * The value is bound as a SQL parameter in Rust — never interpolated.
 */
char *rga_store_put(void *h, const char *key, const char *value);

/**
 * Read one key (v5 Tier 2): `{"key":...,"found":true,"value":...}`,
 * or `{"key":...,"found":false}` when the key does not exist — a
 * missing key is reported as missing, never filled with a
 * placeholder value.
 */
char *rga_store_get(void *h, const char *key);

/**
 * Delete one key (v5 Tier 2): `{"key":...,"existed":bool}` —
 * `existed` reports whether a row was actually there.
 */
char *rga_store_delete(void *h, const char *key);

/**
 * Memory-mapped ring snapshot (v5 Tier 5, memmap2; added
 * 2026-10-23, additive export, ABI stays 2):
 * `{"enabled":bool,"capacity":N,"head":N,"tail":N,
 *   "pending_bytes":N,"pending_messages":N}`.
 * `enabled` is false when the daemon config named no "ring_path" —
 * there is then no ring at all and the counters are the documented
 * zero shape of that state. `pending_bytes` counts record framing
 * and wrap padding along with payload bytes (it is head - tail);
 * `pending_messages` counts whole unconsumed messages.
 */
char *rga_ring_state(void *h);

/**
 * Send one UTF-8 message into the memory-mapped ring (v5 Tier 5):
 * `{"ok":true,"bytes":N}` where N is the payload length. A full
 * ring returns `{"error":"ring_full"}` and the message is NOT
 * queued — nothing is dropped silently and nothing is overwritten.
 * A disabled ring returns `{"error":"ring_disabled"}`.
 */
char *rga_ring_send(void *h, const char *payload);

/**
 * Receive the oldest pending ring message (v5 Tier 5):
 * `{"found":true,"message":...}`, or `{"found":false}` when the
 * ring is empty — NO `message` field at all in that case; an empty
 * ring is reported as empty, never filled with a placeholder. A
 * disabled ring returns `{"error":"ring_disabled"}`. A record that
 * fails CRC/bounds validation (protocol v2) returns
 * `{"error":"ring_corrupt: offset=<logical tail>"}` — the bytes
 * are never delivered and the tail does not advance.
 */
char *rga_ring_recv(void *h);

/**
 * Bounded spawn-budget state (Execution Matrix reality,
 * 2026-10-31, additive exports, ABI stays 2):
 * `{"max":3,"held":N,"free":[slots]}`. The budget gates
 * concurrent agent tasks; it spawns nothing itself.
 * `rga_spawn_acquire` returns `{"ok":true,"slot":N}` or
 * `{"error":"spawn_budget_exhausted"}` — exhaustion is explicit,
 * the task is never silently queued. `rga_spawn_release` takes
 * the slot id and returns `{"ok":true,"slot":N}` or an explicit
 * error for an invalid or not-held slot.
 */
char *rga_spawn_state(void *h);

char *rga_spawn_acquire(void *h);

char *rga_spawn_release(void *h, uint32_t slot);

/**
 * Bounded intent-queue state (Execution Matrix reality,
 * 2026-10-31, additive exports, ABI stays 2):
 * `{"depth":N,"capacity":N,"full":bool}`. The queue is the
 * ingestion stage only; arbitration is the Roundtable + Danny
 * chain on the Dart side, not a second pipeline here.
 * `rga_intent_enqueue` returns `{"ok":true,"depth":N}` or
 * `{"error":"intent_queue_full"}` — a refused intent is never
 * stored and never silently dropped. `rga_intent_dequeue`
 * returns `{"found":true,"intent":...}` or `{"found":false}`.
 */
char *rga_intent_state(void *h);

char *rga_intent_enqueue(void *h, const char *intent);

char *rga_intent_dequeue(void *h);

/**
 * Bounded store sweep (Execution Matrix reality, 2026-10-31,
 * additive exports, ABI stays 2). See reclaim.rs for the honest
 * scope: the kv schema has no timestamps, so no time-based
 * expiry is claimed or built.
 * `rga_reclaim_report` returns `{"entries":N,"persistent":bool,
 * "journal_mode":...,"keys":[...]}` from real SQLite state.
 * `rga_reclaim_delete` takes a JSON array of key strings and
 * returns `{"deleted":[...],"missing":[...]}` — only named keys
 * are touched. `rga_reclaim_trim` takes a caller-supplied cap
 * (must be > 0) and deletes oldest-first (rowid order) beyond it,
 * returning `{"removed":[...],"remaining":N}`.
 */
char *rga_reclaim_report(void *h);

char *rga_reclaim_delete(void *h, const char *keys_json);

char *rga_reclaim_trim(void *h, uint32_t cap);

/**
 * Frees a string allocated by this library. Null is a safe no-op.
 * NEVER call this on the static pointer from `rga_version`.
 */
void rga_string_free(char *ptr);
