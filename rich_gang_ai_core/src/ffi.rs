//! extern "C" FFI surface.
//!
//! OWNERSHIP CONTRACT — read before calling from Dart/Kotlin:
//! * Every `*mut c_char` returned by this file was allocated with
//!   `CString::into_raw` and MUST be freed exactly once by the caller via
//!   `rga_string_free`. No exceptions.
//! * The single exception is `rga_version`, which returns a `*const c_char`
//!   pointing at a static string. NEVER pass it to `rga_string_free`.
//! * Handles returned by `rga_daemon_start` must be passed to
//!   `rga_daemon_stop` exactly once; `stop` is idempotent and a no-op on
//!   an invalid handle, so a defensive second call is safe.
//!
//! RULES enforced in every function below:
//! * JSON is built ONLY with `serde_json::json!` / serde serialisation.
//!   Never `format!`, never string interpolation.
//! * Every function taking a handle calls `handle::is_live` first.
//! * Every body is wrapped in `catch_unwind`; a panic becomes a structured
//!   error (or a documented sentinel), never an unwind across the ABI.

use std::ffi::{c_char, c_void, CStr, CString};
use std::panic::{catch_unwind, AssertUnwindSafe};

use crate::{handle, logging, Daemon};

pub const ABI_VERSION: u32 = 2;

fn json_ptr(v: serde_json::Value) -> *mut c_char {
    // serde_json output never contains an interior NUL byte (control chars
    // are escaped), so CString::new can only fail on a programming error;
    // fall back to a static-shaped error document rather than panicking.
    match CString::new(v.to_string()) {
        Ok(s) => s.into_raw(),
        Err(_) => CString::new("{\"error\":\"encode_failure\"}")
            .expect("static error json is valid")
            .into_raw(),
    }
}

fn error_ptr(code: &str) -> *mut c_char {
    json_ptr(serde_json::json!({ "error": code }))
}

fn daemon_ref<'a>(h: *mut c_void) -> Option<&'a Daemon> {
    if !handle::is_live(h) {
        return None;
    }
    // SAFETY: is_live guarantees the pointer was registered by
    // rga_daemon_start and not yet unregistered by rga_daemon_stop, so it
    // still points at a live Daemon allocation.
    unsafe { (h as *const Daemon).as_ref() }
}

fn cstr_arg<'a>(p: *const c_char, name: &str) -> Result<&'a str, *mut c_char> {
    if p.is_null() {
        return Err(json_ptr(serde_json::json!({
            "error": "invalid_argument",
            "argument": name,
            "detail": "null pointer",
        })));
    }
    // SAFETY: callers pass NUL-terminated C strings per the header contract.
    let cs = unsafe { CStr::from_ptr(p) };
    cs.to_str().map_err(|_| {
        json_ptr(serde_json::json!({
            "error": "invalid_argument",
            "argument": name,
            "detail": "not valid UTF-8",
        }))
    })
}

/// Bump on ANY signature change in this file. Currently 2
/// (v2 added rga_personas / rga_remember / rga_recall /
/// rga_witness_facts / rga_witness_statement / rga_dream_broadcast;
/// rga_witnesses, rga_scene_state and rga_affect_grammar were added
/// later as purely additive exports; rga_topology_state and
/// rga_topology_reaches were added 2026-10-22 as purely additive
/// exports, ABI stays 2; rga_store_state / rga_store_put /
/// rga_store_get / rga_store_delete were added 2026-10-23 as purely
/// additive exports, ABI stays 2; rga_ring_state / rga_ring_send /
/// rga_ring_recv were added 2026-10-23 as purely additive exports,
/// ABI stays 2; rga_spawn_state / rga_spawn_acquire /
/// rga_spawn_release / rga_intent_state / rga_intent_enqueue /
/// rga_intent_dequeue / rga_reclaim_report / rga_reclaim_delete /
/// rga_reclaim_trim were added 2026-10-31 as purely additive
/// exports (Execution Matrix reality), ABI stays 2).
#[no_mangle]
pub extern "C" fn rga_abi_version() -> u32 {
    ABI_VERSION
}

/// Static version string. Do NOT free.
#[no_mangle]
pub extern "C" fn rga_version() -> *const c_char {
    concat!("rich_gang_ai_core/", env!("CARGO_PKG_VERSION"), "\0").as_ptr() as *const c_char
}

#[no_mangle]
pub extern "C" fn rga_daemon_start(config_json: *const c_char) -> *mut c_void {
    logging::init();
    log::debug!("rga_daemon_start: entry");
    let result = catch_unwind(AssertUnwindSafe(|| {
        let cfg: &str = if config_json.is_null() {
            "{}"
        } else {
            // SAFETY: header contract — NUL-terminated C string or null.
            match unsafe { CStr::from_ptr(config_json) }.to_str() {
                Ok(s) => s,
                Err(e) => {
                    log::error!("rga_daemon_start: config not UTF-8: {}", e);
                    return std::ptr::null_mut();
                }
            }
        };
        match Daemon::new(cfg) {
            Ok(d) => {
                let h = Box::into_raw(Box::new(d)) as *mut c_void;
                handle::register(h);
                // Milestone 1 proof line: `adb logcat -s RGA.Rust` shows this.
                log::info!("[RICHARD] daemon online");
                log::debug!("rga_daemon_start: exit ok");
                h
            }
            Err(e) => {
                log::error!("rga_daemon_start: {}", e);
                std::ptr::null_mut()
            }
        }
    }));
    result.unwrap_or_else(|_| {
        log::error!("rga_daemon_start: panic caught at FFI boundary");
        std::ptr::null_mut()
    })
}

/// Idempotent. No-op on an invalid or already-stopped handle.
#[no_mangle]
pub extern "C" fn rga_daemon_stop(h: *mut c_void) {
    log::debug!("rga_daemon_stop: entry");
    let _ = catch_unwind(AssertUnwindSafe(|| {
        // Unregister FIRST so no other call can observe the handle as live
        // while the allocation is being dropped.
        if handle::unregister(h) {
            // SAFETY: unregister succeeded exactly once, so this is the only
            // code path that can reconstruct and drop this Box.
            unsafe {
                drop(Box::from_raw(h as *mut Daemon));
            }
            log::info!("daemon stopped");
        } else {
            log::debug!("rga_daemon_stop: invalid handle, no-op");
        }
    }));
    log::debug!("rga_daemon_stop: exit");
}

#[no_mangle]
pub extern "C" fn rga_agent_query(
    h: *mut c_void,
    persona: *const c_char,
    input: *const c_char,
) -> *mut c_char {
    log::debug!("rga_agent_query: entry");
    let out = catch_unwind(AssertUnwindSafe(|| {
        let Some(d) = daemon_ref(h) else {
            return error_ptr("invalid_handle");
        };
        let persona = match cstr_arg(persona, "persona") {
            Ok(s) => s,
            Err(e) => return e,
        };
        let input = match cstr_arg(input, "input") {
            Ok(s) => s,
            Err(e) => return e,
        };
        if !d.knows_persona(persona) {
            return json_ptr(serde_json::json!({
                "error": "unknown_persona",
                "persona": persona,
            }));
        }
        // No inference lives in Rust, and this endpoint NEVER fabricates
        // reply text (Richard's standing rule, 2026-10-21: no mock data,
        // no mock math, no canned answers). Persona replies come only
        // from the Dart InferenceRouter (NVIDIA primary, Ollama local).
        // When routing has no provider, the honest answer is an error
        // the UI renders as "inference unavailable" — not a fake reply.
        // (The Milestones 1–3 deterministic stub that used to live here
        // was removed for exactly this reason.)
        let _ = input; // accepted for signature stability; not answered here
        json_ptr(serde_json::json!({
            "error": "inference_unavailable",
            "detail": "the Rust daemon does not generate replies; use the Dart InferenceRouter (NVIDIA/Ollama)",
            "persona": persona,
            "memory_items": d.memory_len(),
        }))
    }))
    .unwrap_or_else(|_| {
        log::error!("rga_agent_query: panic caught at FFI boundary");
        error_ptr("panic")
    });
    log::debug!("rga_agent_query: exit");
    out
}

/// Returns 0 on an invalid handle.
#[no_mangle]
pub extern "C" fn rga_dream_cycle_tick(h: *mut c_void) -> u64 {
    log::debug!("rga_dream_cycle_tick: entry");
    let out = catch_unwind(AssertUnwindSafe(|| match daemon_ref(h) {
        Some(d) => {
            let n = d.tick();
            log::info!("dream cycle tick={}", n);
            n
        }
        None => 0,
    }))
    .unwrap_or(0);
    log::debug!("rga_dream_cycle_tick: exit");
    out
}

/// Applies one AffectFrame proposal to the scene. Always returns a JSON
/// document: a Delta on success, a Reject on any validation failure.
#[no_mangle]
pub extern "C" fn rga_scene_apply(h: *mut c_void, proposal_json: *const c_char) -> *mut c_char {
    log::debug!("rga_scene_apply: entry");
    let out = catch_unwind(AssertUnwindSafe(|| {
        let Some(d) = daemon_ref(h) else {
            return error_ptr("invalid_handle");
        };
        let text = match cstr_arg(proposal_json, "proposal_json") {
            Ok(s) => s,
            Err(e) => return e,
        };
        let frame: crate::scene::AffectFrame = match serde_json::from_str(text) {
            Ok(f) => f,
            Err(e) => {
                return json_ptr(serde_json::json!({
                    "status": "reject",
                    "reason": "schema",
                    "detail": e.to_string(),
                }));
            }
        };
        let mut scene = d.scene.lock();
        match scene.apply(frame) {
            Ok(delta) => json_ptr(
                serde_json::to_value(delta).unwrap_or_else(|_| serde_json::json!({"status":"reject","reason":"encode","detail":"delta serialisation failed"})),
            ),
            Err(reject) => json_ptr(
                serde_json::to_value(reject).unwrap_or_else(|_| serde_json::json!({"status":"reject","reason":"encode","detail":"reject serialisation failed"})),
            ),
        }
    }))
    .unwrap_or_else(|_| {
        log::error!("rga_scene_apply: panic caught at FFI boundary");
        error_ptr("panic")
    });
    log::debug!("rga_scene_apply: exit");
    out
}

/// Current scene state as a JSON snapshot: accepted-frame count, last
/// beat, and the last ACCEPTED Delta (post-clamp), or
/// `"last_delta": null` before any frame has been accepted. This is
/// the Performance Director's only input — real state, read live.
#[no_mangle]
pub extern "C" fn rga_scene_state(h: *mut c_void) -> *mut c_char {
    let out = catch_unwind(AssertUnwindSafe(|| {
        let Some(d) = daemon_ref(h) else {
            return error_ptr("invalid_handle");
        };
        let scene = d.scene.lock();
        json_ptr(
            serde_json::to_value(scene.snapshot()).unwrap_or_else(|_| {
                serde_json::json!({"error": "encode_failure"})
            }),
        )
    }))
    .unwrap_or_else(|_| error_ptr("panic"));
    out
}

/// The GBNF grammar for the AffectFrame schema (build order step 3),
/// as plain text (NOT JSON). Ownership follows the file contract: the
/// returned `*mut c_char` must be freed once via `rga_string_free`.
#[no_mangle]
pub extern "C" fn rga_affect_grammar() -> *mut c_char {
    let out = catch_unwind(AssertUnwindSafe(|| {
        match CString::new(crate::scene::AFFECT_GRAMMAR_GBNF) {
            Ok(s) => s.into_raw(),
            Err(_) => error_ptr("encode_failure"),
        }
    }))
    .unwrap_or_else(|_| error_ptr("panic"));
    out
}

/// Persona roster as `{"personas":["leo", ...]}`.
#[no_mangle]
pub extern "C" fn rga_personas(h: *mut c_void) -> *mut c_char {
    let out = catch_unwind(AssertUnwindSafe(|| {
        let Some(d) = daemon_ref(h) else {
            return error_ptr("invalid_handle");
        };
        json_ptr(serde_json::json!({ "personas": d.personas() }))
    }))
    .unwrap_or_else(|_| error_ptr("panic"));
    out
}

/// Store one memory locally. `{"ok":true,"count":N}` or an error doc.
#[no_mangle]
pub extern "C" fn rga_remember(
    h: *mut c_void,
    id: *const c_char,
    text: *const c_char,
) -> *mut c_char {
    let out = catch_unwind(AssertUnwindSafe(|| {
        let Some(d) = daemon_ref(h) else {
            return error_ptr("invalid_handle");
        };
        let id = match cstr_arg(id, "id") {
            Ok(s) => s,
            Err(e) => return e,
        };
        let text = match cstr_arg(text, "text") {
            Ok(s) => s,
            Err(e) => return e,
        };
        let n = d.remember(id, text);
        json_ptr(serde_json::json!({ "ok": true, "count": n }))
    }))
    .unwrap_or_else(|_| error_ptr("panic"));
    out
}

/// Recall memories similar to `query`. `{"results":[{id,payload,score}]}`
#[no_mangle]
pub extern "C" fn rga_recall(
    h: *mut c_void,
    query: *const c_char,
    k: u32,
) -> *mut c_char {
    let out = catch_unwind(AssertUnwindSafe(|| {
        let Some(d) = daemon_ref(h) else {
            return error_ptr("invalid_handle");
        };
        let query = match cstr_arg(query, "query") {
            Ok(s) => s,
            Err(e) => return e,
        };
        let results: Vec<serde_json::Value> = d
            .recall(query, k as usize)
            .into_iter()
            .map(|(id, payload, score)| {
                serde_json::json!({ "id": id, "payload": payload, "score": score })
            })
            .collect();
        json_ptr(serde_json::json!({ "results": results }))
    }))
    .unwrap_or_else(|_| error_ptr("panic"));
    out
}

/// Facts a witness knows: `{"witness":..., "facts":[{id,text,lie_permitted}]}`
/// The lie text and the truth behind a permitted lie are NOT included —
/// a witness prompt must never receive them from this function beyond
/// what `rga_witness_statement` gives in play; cross-referencing data
/// stays player-side. Unknown witness -> structured error.
#[no_mangle]
pub extern "C" fn rga_witness_facts(
    h: *mut c_void,
    witness: *const c_char,
) -> *mut c_char {
    let out = catch_unwind(AssertUnwindSafe(|| {
        let Some(d) = daemon_ref(h) else {
            return error_ptr("invalid_handle");
        };
        let witness = match cstr_arg(witness, "witness") {
            Ok(s) => s,
            Err(e) => return e,
        };
        match d.facts().witness_facts(witness) {
            Some(facts) => {
                let list: Vec<serde_json::Value> = facts
                    .iter()
                    .map(|f| {
                        serde_json::json!({
                            "id": f.id,
                            "text": f.text,
                            "lie_permitted": f.lie_permitted,
                        })
                    })
                    .collect();
                json_ptr(serde_json::json!({ "witness": witness, "facts": list }))
            }
            None => json_ptr(serde_json::json!({
                "error": "unknown_witness",
                "witness": witness,
            })),
        }
    }))
    .unwrap_or_else(|_| error_ptr("panic"));
    out
}

/// List the witness names in the loaded fact table:
/// `{"witnesses": ["...", ...]}`. Empty when no scene is loaded — the
/// UI renders its empty state from this, never from hardcoded names.
/// (Added 2026-10-21 when the built-in scene was removed; additive
/// export, ABI stays 2.)
#[no_mangle]
pub extern "C" fn rga_witnesses(h: *mut c_void) -> *mut c_char {
    let out = catch_unwind(AssertUnwindSafe(|| {
        let Some(d) = daemon_ref(h) else {
            return error_ptr("invalid_handle");
        };
        let names: Vec<&str> = d.facts().witness_names();
        json_ptr(serde_json::json!({ "witnesses": names }))
    }))
    .unwrap_or_else(|_| error_ptr("panic"));
    out
}

/// The in-play statement for one fact: `{"statement": "..."}` — the lie
/// version when lying is permitted — or `{"error":"unknown_fact"}` when
/// the witness does not know it (UI renders "I don't know").
#[no_mangle]
pub extern "C" fn rga_witness_statement(
    h: *mut c_void,
    witness: *const c_char,
    fact_id: *const c_char,
) -> *mut c_char {
    let out = catch_unwind(AssertUnwindSafe(|| {
        let Some(d) = daemon_ref(h) else {
            return error_ptr("invalid_handle");
        };
        let witness = match cstr_arg(witness, "witness") {
            Ok(s) => s,
            Err(e) => return e,
        };
        let fact_id = match cstr_arg(fact_id, "fact_id") {
            Ok(s) => s,
            Err(e) => return e,
        };
        match d.facts().statement_for(witness, fact_id) {
            Some(s) => json_ptr(serde_json::json!({ "statement": s })),
            None => json_ptr(serde_json::json!({
                "error": "unknown_fact",
                "witness": witness,
                "fact_id": fact_id,
            })),
        }
    }))
    .unwrap_or_else(|_| error_ptr("panic"));
    out
}

/// Produce a text-only dream broadcast. Advances the tick counter,
/// stores the broadcast, returns `{"ok":true,"tick":N,"broadcast":"..."}`.
#[no_mangle]
pub extern "C" fn rga_dream_broadcast(h: *mut c_void) -> *mut c_char {
    let out = catch_unwind(AssertUnwindSafe(|| {
        let Some(d) = daemon_ref(h) else {
            return error_ptr("invalid_handle");
        };
        let (tick, text) = d.dream_broadcast();
        log::info!("dream broadcast tick={}", tick);
        json_ptr(serde_json::json!({ "ok": true, "tick": tick, "broadcast": text }))
    }))
    .unwrap_or_else(|_| error_ptr("panic"));
    out
}

/// Causal topology snapshot (v5 Tier 3, petgraph; added 2026-10-22,
/// additive export, ABI stays 2):
/// `{"nodes":N,"edges":M,"order":[...]}` — order is the causal
/// ordering (causes before effects). Empty graph (no "causal_links"
/// in the daemon config) returns zero counts and an empty order —
/// an honest empty state, not built-in data. A cyclic graph returns
/// `{"error":"causal_cycle_detected","detail":...,"nodes":N,"edges":M}`.
#[no_mangle]
pub extern "C" fn rga_topology_state(h: *mut c_void) -> *mut c_char {
    let out = catch_unwind(AssertUnwindSafe(|| {
        let Some(d) = daemon_ref(h) else {
            return error_ptr("invalid_handle");
        };
        let t = d.topology();
        match t.causal_order() {
            Ok(order) => json_ptr(serde_json::json!({
                "nodes": t.node_count(),
                "edges": t.edge_count(),
                "order": order,
            })),
            Err(detail) => json_ptr(serde_json::json!({
                "error": "causal_cycle_detected",
                "detail": detail,
                "nodes": t.node_count(),
                "edges": t.edge_count(),
            })),
        }
    }))
    .unwrap_or_else(|_| error_ptr("panic"));
    out
}

/// Multi-hop causal reachability (v5 Tier 3): does `from` causally
/// reach `to` through any chain of config-supplied links?
/// `{"from":...,"to":...,"reaches":bool}` — unknown names are
/// `reaches:false`, never a guess.
#[no_mangle]
pub extern "C" fn rga_topology_reaches(
    h: *mut c_void,
    from: *const c_char,
    to: *const c_char,
) -> *mut c_char {
    let out = catch_unwind(AssertUnwindSafe(|| {
        let Some(d) = daemon_ref(h) else {
            return error_ptr("invalid_handle");
        };
        let from = match cstr_arg(from, "from") {
            Ok(s) => s,
            Err(e) => return e,
        };
        let to = match cstr_arg(to, "to") {
            Ok(s) => s,
            Err(e) => return e,
        };
        json_ptr(serde_json::json!({
            "from": from,
            "to": to,
            "reaches": d.topology().causally_reaches(from, to),
        }))
    }))
    .unwrap_or_else(|_| error_ptr("panic"));
    out
}

/// Persistent store snapshot (v5 Tier 2, rusqlite; added 2026-10-23,
/// additive export, ABI stays 2):
/// `{"persistent":bool,"journal_mode":...,"entries":N,"sqlite_version":...}`.
/// `persistent` is false when the daemon config named no
/// "store_path" — the store is then in-memory for this session only,
/// and this document says so plainly. A database failure returns
/// `{"error":"store_error","detail":...}`.
#[no_mangle]
pub extern "C" fn rga_store_state(h: *mut c_void) -> *mut c_char {
    let out = catch_unwind(AssertUnwindSafe(|| {
        let Some(d) = daemon_ref(h) else {
            return error_ptr("invalid_handle");
        };
        let s = d.store();
        match s.count() {
            Ok(entries) => json_ptr(serde_json::json!({
                "persistent": s.is_persistent(),
                "journal_mode": s.journal_mode(),
                "entries": entries,
                "sqlite_version": crate::store::SqlStore::sqlite_version(),
            })),
            Err(detail) => json_ptr(serde_json::json!({
                "error": "store_error",
                "detail": detail,
            })),
        }
    }))
    .unwrap_or_else(|_| error_ptr("panic"));
    out
}

/// Store one key/value pair (v5 Tier 2): `{"ok":true,"key":...}`.
/// The value is bound as a SQL parameter in Rust — never interpolated.
#[no_mangle]
pub extern "C" fn rga_store_put(
    h: *mut c_void,
    key: *const c_char,
    value: *const c_char,
) -> *mut c_char {
    let out = catch_unwind(AssertUnwindSafe(|| {
        let Some(d) = daemon_ref(h) else {
            return error_ptr("invalid_handle");
        };
        let key = match cstr_arg(key, "key") {
            Ok(s) => s,
            Err(e) => return e,
        };
        let value = match cstr_arg(value, "value") {
            Ok(s) => s,
            Err(e) => return e,
        };
        match d.store().put(key, value) {
            Ok(()) => json_ptr(serde_json::json!({ "ok": true, "key": key })),
            Err(detail) => json_ptr(serde_json::json!({
                "error": "store_error",
                "detail": detail,
            })),
        }
    }))
    .unwrap_or_else(|_| error_ptr("panic"));
    out
}

/// Read one key (v5 Tier 2): `{"key":...,"found":true,"value":...}`,
/// or `{"key":...,"found":false}` when the key does not exist — a
/// missing key is reported as missing, never filled with a
/// placeholder value.
#[no_mangle]
pub extern "C" fn rga_store_get(h: *mut c_void, key: *const c_char) -> *mut c_char {
    let out = catch_unwind(AssertUnwindSafe(|| {
        let Some(d) = daemon_ref(h) else {
            return error_ptr("invalid_handle");
        };
        let key = match cstr_arg(key, "key") {
            Ok(s) => s,
            Err(e) => return e,
        };
        match d.store().get(key) {
            Ok(Some(value)) => json_ptr(serde_json::json!({
                "key": key,
                "found": true,
                "value": value,
            })),
            Ok(None) => json_ptr(serde_json::json!({
                "key": key,
                "found": false,
            })),
            Err(detail) => json_ptr(serde_json::json!({
                "error": "store_error",
                "detail": detail,
            })),
        }
    }))
    .unwrap_or_else(|_| error_ptr("panic"));
    out
}

/// Delete one key (v5 Tier 2): `{"key":...,"existed":bool}` —
/// `existed` reports whether a row was actually there.
#[no_mangle]
pub extern "C" fn rga_store_delete(h: *mut c_void, key: *const c_char) -> *mut c_char {
    let out = catch_unwind(AssertUnwindSafe(|| {
        let Some(d) = daemon_ref(h) else {
            return error_ptr("invalid_handle");
        };
        let key = match cstr_arg(key, "key") {
            Ok(s) => s,
            Err(e) => return e,
        };
        match d.store().delete(key) {
            Ok(existed) => json_ptr(serde_json::json!({
                "key": key,
                "existed": existed,
            })),
            Err(detail) => json_ptr(serde_json::json!({
                "error": "store_error",
                "detail": detail,
            })),
        }
    }))
    .unwrap_or_else(|_| error_ptr("panic"));
    out
}

/// Memory-mapped ring snapshot (v5 Tier 5, memmap2; added
/// 2026-10-23, additive export, ABI stays 2):
/// `{"enabled":bool,"capacity":N,"head":N,"tail":N,
///   "pending_bytes":N,"pending_messages":N}`.
/// `enabled` is false when the daemon config named no "ring_path" —
/// there is then no ring at all and the counters are the documented
/// zero shape of that state. `pending_bytes` counts record framing
/// and wrap padding along with payload bytes (it is head - tail);
/// `pending_messages` counts whole unconsumed messages.
#[no_mangle]
pub extern "C" fn rga_ring_state(h: *mut c_void) -> *mut c_char {
    let out = catch_unwind(AssertUnwindSafe(|| {
        let Some(d) = daemon_ref(h) else {
            return error_ptr("invalid_handle");
        };
        let s = d.ring().state();
        json_ptr(serde_json::json!({
            "enabled": s.enabled,
            "capacity": s.capacity,
            "head": s.head,
            "tail": s.tail,
            "pending_bytes": s.pending_bytes,
            "pending_messages": s.pending_messages,
        }))
    }))
    .unwrap_or_else(|_| error_ptr("panic"));
    out
}

/// Send one UTF-8 message into the memory-mapped ring (v5 Tier 5):
/// `{"ok":true,"bytes":N}` where N is the payload length. A full
/// ring returns `{"error":"ring_full"}` and the message is NOT
/// queued — nothing is dropped silently and nothing is overwritten.
/// A disabled ring returns `{"error":"ring_disabled"}`.
#[no_mangle]
pub extern "C" fn rga_ring_send(h: *mut c_void, payload: *const c_char) -> *mut c_char {
    let out = catch_unwind(AssertUnwindSafe(|| {
        let Some(d) = daemon_ref(h) else {
            return error_ptr("invalid_handle");
        };
        let payload = match cstr_arg(payload, "payload") {
            Ok(s) => s,
            Err(e) => return e,
        };
        match d.ring().send(payload.as_bytes()) {
            Ok(()) => json_ptr(serde_json::json!({
                "ok": true,
                "bytes": payload.len(),
            })),
            Err(detail) => json_ptr(serde_json::json!({
                "error": detail,
            })),
        }
    }))
    .unwrap_or_else(|_| error_ptr("panic"));
    out
}

/// Receive the oldest pending ring message (v5 Tier 5):
/// `{"found":true,"message":...}`, or `{"found":false}` when the
/// ring is empty — NO `message` field at all in that case; an empty
/// ring is reported as empty, never filled with a placeholder. A
/// disabled ring returns `{"error":"ring_disabled"}`. A record that
/// fails CRC/bounds validation (protocol v2) returns
/// `{"error":"ring_corrupt: offset=<logical tail>"}` — the bytes
/// are never delivered and the tail does not advance.
#[no_mangle]
pub extern "C" fn rga_ring_recv(h: *mut c_void) -> *mut c_char {
    let out = catch_unwind(AssertUnwindSafe(|| {
        let Some(d) = daemon_ref(h) else {
            return error_ptr("invalid_handle");
        };
        match d.ring().recv() {
            Ok(Some(bytes)) => match String::from_utf8(bytes) {
                Ok(message) => json_ptr(serde_json::json!({
                    "found": true,
                    "message": message,
                })),
                Err(_) => json_ptr(serde_json::json!({
                    "error": "ring_error",
                    "detail": "ring_message_not_utf8",
                })),
            },
            Ok(None) => json_ptr(serde_json::json!({
                "found": false,
            })),
            Err(detail) => json_ptr(serde_json::json!({
                "error": detail,
            })),
        }
    }))
    .unwrap_or_else(|_| error_ptr("panic"));
    out
}

/// Bounded spawn-budget state (Execution Matrix reality,
/// 2026-10-31, additive exports, ABI stays 2):
/// `{"max":3,"held":N,"free":[slots]}`. The budget gates
/// concurrent agent tasks; it spawns nothing itself.
/// `rga_spawn_acquire` returns `{"ok":true,"slot":N}` or
/// `{"error":"spawn_budget_exhausted"}` — exhaustion is explicit,
/// the task is never silently queued. `rga_spawn_release` takes
/// the slot id and returns `{"ok":true,"slot":N}` or an explicit
/// error for an invalid or not-held slot.
#[no_mangle]
pub extern "C" fn rga_spawn_state(h: *mut c_void) -> *mut c_char {
    let out = catch_unwind(AssertUnwindSafe(|| {
        let Some(d) = daemon_ref(h) else {
            return error_ptr("invalid_handle");
        };
        let (max, held, free) = d.spawn_state();
        json_ptr(serde_json::json!({
            "max": max,
            "held": held,
            "free": free,
        }))
    }))
    .unwrap_or_else(|_| error_ptr("panic"));
    out
}

#[no_mangle]
pub extern "C" fn rga_spawn_acquire(h: *mut c_void) -> *mut c_char {
    let out = catch_unwind(AssertUnwindSafe(|| {
        let Some(d) = daemon_ref(h) else {
            return error_ptr("invalid_handle");
        };
        match d.spawn_acquire() {
            Ok(slot) => json_ptr(serde_json::json!({ "ok": true, "slot": slot })),
            Err(detail) => json_ptr(serde_json::json!({ "error": detail })),
        }
    }))
    .unwrap_or_else(|_| error_ptr("panic"));
    out
}

#[no_mangle]
pub extern "C" fn rga_spawn_release(h: *mut c_void, slot: u32) -> *mut c_char {
    let out = catch_unwind(AssertUnwindSafe(|| {
        let Some(d) = daemon_ref(h) else {
            return error_ptr("invalid_handle");
        };
        match d.spawn_release(slot as usize) {
            Ok(()) => json_ptr(serde_json::json!({ "ok": true, "slot": slot })),
            Err(detail) => json_ptr(serde_json::json!({ "error": detail })),
        }
    }))
    .unwrap_or_else(|_| error_ptr("panic"));
    out
}

/// Bounded intent-queue state (Execution Matrix reality,
/// 2026-10-31, additive exports, ABI stays 2):
/// `{"depth":N,"capacity":N,"full":bool}`. The queue is the
/// ingestion stage only; arbitration is the Roundtable + Danny
/// chain on the Dart side, not a second pipeline here.
/// `rga_intent_enqueue` returns `{"ok":true,"depth":N}` or
/// `{"error":"intent_queue_full"}` — a refused intent is never
/// stored and never silently dropped. `rga_intent_dequeue`
/// returns `{"found":true,"intent":...}` or `{"found":false}`.
#[no_mangle]
pub extern "C" fn rga_intent_state(h: *mut c_void) -> *mut c_char {
    let out = catch_unwind(AssertUnwindSafe(|| {
        let Some(d) = daemon_ref(h) else {
            return error_ptr("invalid_handle");
        };
        let (depth, capacity, full) = d.intent_state();
        json_ptr(serde_json::json!({
            "depth": depth,
            "capacity": capacity,
            "full": full,
        }))
    }))
    .unwrap_or_else(|_| error_ptr("panic"));
    out
}

#[no_mangle]
pub extern "C" fn rga_intent_enqueue(
    h: *mut c_void,
    intent: *const c_char,
) -> *mut c_char {
    let out = catch_unwind(AssertUnwindSafe(|| {
        let Some(d) = daemon_ref(h) else {
            return error_ptr("invalid_handle");
        };
        let intent = match cstr_arg(intent, "intent") {
            Ok(s) => s,
            Err(e) => return e,
        };
        match d.intent_enqueue(intent.to_string()) {
            Ok(depth) => json_ptr(serde_json::json!({ "ok": true, "depth": depth })),
            Err(detail) => json_ptr(serde_json::json!({ "error": detail })),
        }
    }))
    .unwrap_or_else(|_| error_ptr("panic"));
    out
}

#[no_mangle]
pub extern "C" fn rga_intent_dequeue(h: *mut c_void) -> *mut c_char {
    let out = catch_unwind(AssertUnwindSafe(|| {
        let Some(d) = daemon_ref(h) else {
            return error_ptr("invalid_handle");
        };
        match d.intent_dequeue() {
            Some(intent) => json_ptr(serde_json::json!({
                "found": true,
                "intent": intent,
            })),
            None => json_ptr(serde_json::json!({ "found": false })),
        }
    }))
    .unwrap_or_else(|_| error_ptr("panic"));
    out
}

/// Bounded store sweep (Execution Matrix reality, 2026-10-31,
/// additive exports, ABI stays 2). See reclaim.rs for the honest
/// scope: the kv schema has no timestamps, so no time-based
/// expiry is claimed or built.
/// `rga_reclaim_report` returns `{"entries":N,"persistent":bool,
/// "journal_mode":...,"keys":[...]}` from real SQLite state.
/// `rga_reclaim_delete` takes a JSON array of key strings and
/// returns `{"deleted":[...],"missing":[...]}` — only named keys
/// are touched. `rga_reclaim_trim` takes a caller-supplied cap
/// (must be > 0) and deletes oldest-first (rowid order) beyond it,
/// returning `{"removed":[...],"remaining":N}`.
#[no_mangle]
pub extern "C" fn rga_reclaim_report(h: *mut c_void) -> *mut c_char {
    let out = catch_unwind(AssertUnwindSafe(|| {
        let Some(d) = daemon_ref(h) else {
            return error_ptr("invalid_handle");
        };
        match crate::reclaim::report(d.store()) {
            Ok(r) => json_ptr(serde_json::json!({
                "entries": r.entries,
                "persistent": r.persistent,
                "journal_mode": r.journal_mode,
                "keys": r.keys,
            })),
            Err(detail) => json_ptr(serde_json::json!({
                "error": "store_error",
                "detail": detail,
            })),
        }
    }))
    .unwrap_or_else(|_| error_ptr("panic"));
    out
}

#[no_mangle]
pub extern "C" fn rga_reclaim_delete(
    h: *mut c_void,
    keys_json: *const c_char,
) -> *mut c_char {
    let out = catch_unwind(AssertUnwindSafe(|| {
        let Some(d) = daemon_ref(h) else {
            return error_ptr("invalid_handle");
        };
        let keys_json = match cstr_arg(keys_json, "keys_json") {
            Ok(s) => s,
            Err(e) => return e,
        };
        let keys: Vec<String> = match serde_json::from_str(keys_json) {
            Ok(v) => v,
            Err(_) => {
                return json_ptr(serde_json::json!({
                    "error": "invalid_argument",
                    "argument": "keys_json",
                    "detail": "expected a JSON array of key strings",
                }));
            }
        };
        match crate::reclaim::delete_named(d.store(), &keys) {
            Ok(r) => json_ptr(serde_json::json!({
                "deleted": r.deleted,
                "missing": r.missing,
            })),
            Err(detail) => json_ptr(serde_json::json!({
                "error": "store_error",
                "detail": detail,
            })),
        }
    }))
    .unwrap_or_else(|_| error_ptr("panic"));
    out
}

#[no_mangle]
pub extern "C" fn rga_reclaim_trim(h: *mut c_void, cap: u32) -> *mut c_char {
    let out = catch_unwind(AssertUnwindSafe(|| {
        let Some(d) = daemon_ref(h) else {
            return error_ptr("invalid_handle");
        };
        match crate::reclaim::trim_to_cap(d.store(), cap as usize) {
            Ok(r) => json_ptr(serde_json::json!({
                "removed": r.removed,
                "remaining": r.remaining,
            })),
            Err(detail) => json_ptr(serde_json::json!({
                "error": detail,
            })),
        }
    }))
    .unwrap_or_else(|_| error_ptr("panic"));
    out
}

/// Frees a string allocated by this library. Null is a safe no-op.
/// NEVER call this on the static pointer from `rga_version`.
#[no_mangle]
pub extern "C" fn rga_string_free(ptr: *mut c_char) {
    if ptr.is_null() {
        return;
    }
    let _ = catch_unwind(AssertUnwindSafe(|| {
        // SAFETY: per the ownership contract, ptr came from
        // CString::into_raw in this library and is freed exactly once.
        unsafe {
            drop(CString::from_raw(ptr));
        }
    }));
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::ffi::CString;

    fn start() -> *mut c_void {
        rga_daemon_start(CString::new("{}").unwrap().as_ptr())
    }

    fn start_with(config: &str) -> *mut c_void {
        rga_daemon_start(CString::new(config).unwrap().as_ptr())
    }

    fn take(ptr: *mut c_char) -> String {
        assert!(!ptr.is_null());
        // SAFETY: test-only mirror of the caller contract.
        let s = unsafe { CStr::from_ptr(ptr) }.to_str().unwrap().to_string();
        rga_string_free(ptr);
        s
    }

    #[test]
    fn abi_and_version() {
        assert_eq!(rga_abi_version(), 2);
        let v = unsafe { CStr::from_ptr(rga_version()) }.to_str().unwrap();
        assert!(v.starts_with("rich_gang_ai_core/"));
    }

    #[test]
    fn query_round_trip_and_unknown_persona() {
        let h = start();
        assert!(!h.is_null());
        let ok = take(rga_agent_query(
            h,
            CString::new("leo").unwrap().as_ptr(),
            CString::new("hello room").unwrap().as_ptr(),
        ));
        let v: serde_json::Value = serde_json::from_str(&ok).unwrap();
        // Honest contract (2026-10-21): Rust never fabricates a reply.
        // A known persona gets an explicit inference_unavailable error,
        // with NO reply text and NO stub flag.
        assert_eq!(v["error"], "inference_unavailable");
        assert_eq!(v["persona"], "leo");
        assert!(v.get("reply").is_none(), "no fabricated reply text");
        assert!(v.get("stub").is_none(), "no stub marker");

        let bad = take(rga_agent_query(
            h,
            CString::new("nobody").unwrap().as_ptr(),
            CString::new("hi").unwrap().as_ptr(),
        ));
        let v: serde_json::Value = serde_json::from_str(&bad).unwrap();
        assert_eq!(v["error"], "unknown_persona");
        rga_daemon_stop(h);
    }

    #[test]
    fn invalid_handle_paths() {
        let bad = take(rga_agent_query(
            std::ptr::null_mut(),
            CString::new("leo").unwrap().as_ptr(),
            CString::new("hi").unwrap().as_ptr(),
        ));
        let v: serde_json::Value = serde_json::from_str(&bad).unwrap();
        assert_eq!(v["error"], "invalid_handle");
        assert_eq!(rga_dream_cycle_tick(std::ptr::null_mut()), 0);
        // stop on invalid handle: idempotent no-op, must not crash.
        rga_daemon_stop(std::ptr::null_mut());
    }

    #[test]
    fn personas_remember_recall_and_broadcast() {
        let h = start();
        let p = take(rga_personas(h));
        let v: serde_json::Value = serde_json::from_str(&p).unwrap();
        assert!(v["personas"].as_array().unwrap().iter().any(|x| x == "leo"));

        let r = take(rga_remember(
            h,
            CString::new("m1").unwrap().as_ptr(),
            CString::new("the grey sedan left at night").unwrap().as_ptr(),
        ));
        let v: serde_json::Value = serde_json::from_str(&r).unwrap();
        assert_eq!(v["count"], 1);

        let r = take(rga_recall(h, CString::new("sedan night").unwrap().as_ptr(), 3));
        let v: serde_json::Value = serde_json::from_str(&r).unwrap();
        assert_eq!(v["results"][0]["id"], "m1");

        let b = take(rga_dream_broadcast(h));
        let v: serde_json::Value = serde_json::from_str(&b).unwrap();
        assert_eq!(v["ok"], true);
        assert!(v["tick"].as_u64().unwrap() >= 1);
        assert!(v["broadcast"].as_str().unwrap().contains("Dream cycle"));
        rga_daemon_stop(h);
    }

    #[test]
    fn witness_facts_and_statement() {
        // Scene data comes from config only (2026-10-21 removal of the
        // built-in scene). Minimal inline fixture, test-only.
        let h = start_with(
            r#"{"facts":{"witnesses":{"ada":[
                {"id":"door","text":"The door was red.","lie_permitted":true,"lie_text":"The door was blue."},
                {"id":"bell","text":"I heard the bell ring.","lie_permitted":false}
            ]}}}"#,
        );
        assert!(!h.is_null());

        // The witness list is data-driven.
        let w = take(rga_witnesses(h));
        let v: serde_json::Value = serde_json::from_str(&w).unwrap();
        assert_eq!(v["witnesses"], serde_json::json!(["ada"]));

        let f = take(rga_witness_facts(h, CString::new("ada").unwrap().as_ptr()));
        let v: serde_json::Value = serde_json::from_str(&f).unwrap();
        assert_eq!(v["witness"], "ada");
        assert_eq!(v["facts"].as_array().unwrap().len(), 2);
        // The FFI facts view must not leak lie text or the lie field.
        assert!(!f.contains("blue"), "lie text leaked into facts view: {f}");
        assert!(!f.contains("lie_text"), "lie field leaked into facts view: {f}");

        // In play, the permitted lie is the statement given...
        let s = take(rga_witness_statement(
            h,
            CString::new("ada").unwrap().as_ptr(),
            CString::new("door").unwrap().as_ptr(),
        ));
        let v: serde_json::Value = serde_json::from_str(&s).unwrap();
        assert!(v["statement"].as_str().unwrap().contains("blue"));
        // ...a truth-only fact states the truth...
        let s = take(rga_witness_statement(
            h,
            CString::new("ada").unwrap().as_ptr(),
            CString::new("bell").unwrap().as_ptr(),
        ));
        let v: serde_json::Value = serde_json::from_str(&s).unwrap();
        assert!(v["statement"].as_str().unwrap().contains("bell"));
        // ...and an unknown fact is an explicit error, never invented.
        let u = take(rga_witness_statement(
            h,
            CString::new("ada").unwrap().as_ptr(),
            CString::new("nope").unwrap().as_ptr(),
        ));
        let v: serde_json::Value = serde_json::from_str(&u).unwrap();
        assert_eq!(v["error"], "unknown_fact");
        rga_daemon_stop(h);
    }

    #[test]
    fn no_config_facts_means_no_witnesses() {
        // Regression guard: a daemon booted with {} has an empty scene.
        let h = start();
        let w = take(rga_witnesses(h));
        let v: serde_json::Value = serde_json::from_str(&w).unwrap();
        assert_eq!(v["witnesses"], serde_json::json!([]));
        rga_daemon_stop(h);
    }

    #[test]
    fn topology_state_and_reaches_from_config() {
        let h = start_with(
            r#"{"causal_links":[["sensor","governor"],["governor","downscale"]]}"#,
        );
        assert!(!h.is_null());
        let s = take(rga_topology_state(h));
        let v: serde_json::Value = serde_json::from_str(&s).unwrap();
        assert_eq!(v["nodes"], 3);
        assert_eq!(v["edges"], 2);
        assert_eq!(
            v["order"],
            serde_json::json!(["sensor", "governor", "downscale"])
        );
        // Multi-hop reachability crosses the FFI boundary truthfully.
        let r = take(rga_topology_reaches(
            h,
            CString::new("sensor").unwrap().as_ptr(),
            CString::new("downscale").unwrap().as_ptr(),
        ));
        let v: serde_json::Value = serde_json::from_str(&r).unwrap();
        assert_eq!(v["reaches"], true);
        let r = take(rga_topology_reaches(
            h,
            CString::new("downscale").unwrap().as_ptr(),
            CString::new("sensor").unwrap().as_ptr(),
        ));
        let v: serde_json::Value = serde_json::from_str(&r).unwrap();
        assert_eq!(v["reaches"], false);
        rga_daemon_stop(h);
    }

    #[test]
    fn topology_empty_by_default_and_cycle_is_an_error_doc() {
        // No causal_links in config -> honest empty state.
        let h = start();
        let s = take(rga_topology_state(h));
        let v: serde_json::Value = serde_json::from_str(&s).unwrap();
        assert_eq!(v["nodes"], 0);
        assert_eq!(v["edges"], 0);
        assert_eq!(v["order"], serde_json::json!([]));
        rga_daemon_stop(h);

        // A cycle is a structured error document, never an ordering.
        let h = start_with(r#"{"causal_links":[["a","b"],["b","a"]]}"#);
        let s = take(rga_topology_state(h));
        let v: serde_json::Value = serde_json::from_str(&s).unwrap();
        assert_eq!(v["error"], "causal_cycle_detected");
        assert!(v.get("order").is_none());
        rga_daemon_stop(h);
    }

    #[test]
    fn store_roundtrip_across_ffi_and_missing_key_is_found_false() {
        let h = start();
        // Default config: no store_path -> in-memory, and the state
        // document says so.
        let s = take(rga_store_state(h));
        let v: serde_json::Value = serde_json::from_str(&s).unwrap();
        assert_eq!(v["persistent"], false);
        assert_eq!(v["journal_mode"], "memory");
        assert_eq!(v["entries"], 0);
        assert!(!v["sqlite_version"].as_str().unwrap().is_empty());

        let p = take(rga_store_put(
            h,
            CString::new("agent:dan").unwrap().as_ptr(),
            CString::new("{\"mood\":\"ready\"}").unwrap().as_ptr(),
        ));
        let v: serde_json::Value = serde_json::from_str(&p).unwrap();
        assert_eq!(v["ok"], true);

        let g = take(rga_store_get(
            h,
            CString::new("agent:dan").unwrap().as_ptr(),
        ));
        let v: serde_json::Value = serde_json::from_str(&g).unwrap();
        assert_eq!(v["found"], true);
        assert_eq!(v["value"], "{\"mood\":\"ready\"}");

        // Missing key: found:false and NO value field at all.
        let g = take(rga_store_get(
            h,
            CString::new("ghost").unwrap().as_ptr(),
        ));
        let v: serde_json::Value = serde_json::from_str(&g).unwrap();
        assert_eq!(v["found"], false);
        assert!(v.get("value").is_none());

        let del = take(rga_store_delete(
            h,
            CString::new("agent:dan").unwrap().as_ptr(),
        ));
        let v: serde_json::Value = serde_json::from_str(&del).unwrap();
        assert_eq!(v["existed"], true);
        let del = take(rga_store_delete(
            h,
            CString::new("agent:dan").unwrap().as_ptr(),
        ));
        let v: serde_json::Value = serde_json::from_str(&del).unwrap();
        assert_eq!(v["existed"], false);
        rga_daemon_stop(h);
    }

    #[test]
    fn ring_disabled_by_default_and_send_recv_error_explicitly() {
        let h = start();
        // Default config: no ring_path -> disabled, and the state
        // document says so.
        let s = take(rga_ring_state(h));
        let v: serde_json::Value = serde_json::from_str(&s).unwrap();
        assert_eq!(v["enabled"], false);
        assert_eq!(v["capacity"], 0);
        assert_eq!(v["pending_messages"], 0);

        let r = take(rga_ring_send(
            h,
            CString::new("hello").unwrap().as_ptr(),
        ));
        let v: serde_json::Value = serde_json::from_str(&r).unwrap();
        assert_eq!(v["error"], "ring_disabled");

        let r = take(rga_ring_recv(h));
        let v: serde_json::Value = serde_json::from_str(&r).unwrap();
        assert_eq!(v["error"], "ring_disabled");
        rga_daemon_stop(h);
    }

    #[test]
    fn ring_roundtrip_full_and_empty_across_ffi() {
        let path = std::env::temp_dir().join(format!(
            "rga_ffi_ring_{}.bin",
            std::process::id()
        ));
        let cfg = format!(
            r#"{{"ring_path":"{}","ring_capacity":64}}"#,
            path.display()
        );
        let h = start_with(&cfg);
        assert!(!h.is_null());

        let s = take(rga_ring_state(h));
        let v: serde_json::Value = serde_json::from_str(&s).unwrap();
        assert_eq!(v["enabled"], true);
        assert_eq!(v["capacity"], 64);

        // Empty ring: found:false and NO message field at all.
        let r = take(rga_ring_recv(h));
        let v: serde_json::Value = serde_json::from_str(&r).unwrap();
        assert_eq!(v["found"], false);
        assert!(v.get("message").is_none());

        let r = take(rga_ring_send(
            h,
            CString::new("ping").unwrap().as_ptr(),
        ));
        let v: serde_json::Value = serde_json::from_str(&r).unwrap();
        assert_eq!(v["ok"], true);
        assert_eq!(v["bytes"], 4);

        let s = take(rga_ring_state(h));
        let v: serde_json::Value = serde_json::from_str(&s).unwrap();
        assert_eq!(v["pending_messages"], 1);
        assert_eq!(v["pending_bytes"], 12); // v2: 4 length + 4 payload + 4 CRC

        let r = take(rga_ring_recv(h));
        let v: serde_json::Value = serde_json::from_str(&r).unwrap();
        assert_eq!(v["found"], true);
        assert_eq!(v["message"], "ping");

        // Fill the 64-byte ring: v2 8-byte payloads = 16-byte
        // records. Head already sits at offset 12 (the consumed
        // "ping" record), so 3 records fit (offsets 12..60); a 4th
        // would need 4 bytes of wrap padding + 16 = 20 with only
        // 16 free — an explicit ring_full error.
        for i in 0..3 {
            let msg = format!("msg{i}xxxx"); // 8 bytes
            let r = take(rga_ring_send(
                h,
                CString::new(msg).unwrap().as_ptr(),
            ));
            let v: serde_json::Value = serde_json::from_str(&r).unwrap();
            assert_eq!(v["ok"], true);
        }
        let r = take(rga_ring_send(
            h,
            CString::new("overflow").unwrap().as_ptr(),
        ));
        let v: serde_json::Value = serde_json::from_str(&r).unwrap();
        assert_eq!(v["error"], "ring_full");
        // The first queued message survived the rejected send.
        let r = take(rga_ring_recv(h));
        let v: serde_json::Value = serde_json::from_str(&r).unwrap();
        assert_eq!(v["message"], "msg0xxxx");
        rga_daemon_stop(h);
        std::fs::remove_file(&path).ok();
    }

    #[test]
    fn ring_with_unopenable_path_or_bad_capacity_fails_daemon_start() {
        // Unopenable ring_path must fail the start — no fallback.
        let h = start_with(
            r#"{"ring_path":"/no/such/dir/rga.bin","ring_capacity":256}"#,
        );
        assert!(h.is_null());
        // ring_path with no capacity must fail too — never defaulted.
        let h = start_with(r#"{"ring_path":"/tmp/rga_never.bin"}"#);
        assert!(h.is_null());
    }

    #[test]
    fn store_with_unopenable_path_fails_daemon_start() {
        // An explicit store_path that cannot be opened must fail the
        // start — never a silent fall back to in-memory storage.
        let h = start_with(r#"{"store_path":"/no/such/dir/rga.db"}"#);
        assert!(h.is_null());
    }

    #[test]
    fn tick_counts_and_stop_is_idempotent() {
        let h = start();
        assert_eq!(rga_dream_cycle_tick(h), 1);
        assert_eq!(rga_dream_cycle_tick(h), 2);
        rga_daemon_stop(h);
        rga_daemon_stop(h); // second stop: no-op
        assert_eq!(rga_dream_cycle_tick(h), 0); // dead handle stays dead
    }

    #[test]
    fn spawn_budget_ffi_bound_is_three_and_explicit() {
        let h = start();
        let s = take(rga_spawn_state(h));
        let v: serde_json::Value = serde_json::from_str(&s).unwrap();
        assert_eq!(v["max"], 3);
        assert_eq!(v["held"], 0);
        let mut slots = Vec::new();
        for _ in 0..3 {
            let s = take(rga_spawn_acquire(h));
            let v: serde_json::Value = serde_json::from_str(&s).unwrap();
            assert_eq!(v["ok"], true);
            slots.push(v["slot"].as_u64().unwrap());
        }
        assert_eq!(slots, vec![0, 1, 2]);
        let s = take(rga_spawn_acquire(h));
        let v: serde_json::Value = serde_json::from_str(&s).unwrap();
        assert_eq!(v["error"], "spawn_budget_exhausted");
        let s = take(rga_spawn_release(h, 1));
        let v: serde_json::Value = serde_json::from_str(&s).unwrap();
        assert_eq!(v["ok"], true);
        let s = take(rga_spawn_acquire(h));
        let v: serde_json::Value = serde_json::from_str(&s).unwrap();
        assert_eq!(v["slot"], 1);
        let s = take(rga_spawn_release(h, 1));
        let v: serde_json::Value = serde_json::from_str(&s).unwrap();
        assert_eq!(v["ok"], true);
        let s = take(rga_spawn_release(h, 1));
        let v: serde_json::Value = serde_json::from_str(&s).unwrap();
        assert!(v["error"].as_str().unwrap().contains("not_held"));
        rga_daemon_stop(h);
    }

    #[test]
    fn intent_queue_ffi_is_fifo_and_bounded() {
        let h = start_with(r#"{"intent_queue_capacity":2}"#);
        let s = take(rga_intent_state(h));
        let v: serde_json::Value = serde_json::from_str(&s).unwrap();
        assert_eq!(v["capacity"], 2);
        assert_eq!(v["depth"], 0);
        assert_eq!(v["full"], false);
        let s = take(rga_intent_enqueue(
            h,
            CString::new("first").unwrap().as_ptr(),
        ));
        assert_eq!(
            serde_json::from_str::<serde_json::Value>(&s).unwrap()["depth"],
            1
        );
        let _ = take(rga_intent_enqueue(
            h,
            CString::new("second").unwrap().as_ptr(),
        ));
        let s = take(rga_intent_enqueue(
            h,
            CString::new("third").unwrap().as_ptr(),
        ));
        assert_eq!(
            serde_json::from_str::<serde_json::Value>(&s).unwrap()["error"],
            "intent_queue_full"
        );
        let s = take(rga_intent_dequeue(h));
        let v: serde_json::Value = serde_json::from_str(&s).unwrap();
        assert_eq!(v["found"], true);
        assert_eq!(v["intent"], "first");
        let s = take(rga_intent_dequeue(h));
        let v: serde_json::Value = serde_json::from_str(&s).unwrap();
        assert_eq!(v["intent"], "second");
        let s = take(rga_intent_dequeue(h));
        let v: serde_json::Value = serde_json::from_str(&s).unwrap();
        assert_eq!(v["found"], false);
        rga_daemon_stop(h);
    }

    #[test]
    fn reclaim_ffi_reports_deletes_named_and_trims_oldest() {
        let h = start();
        let _ = take(rga_store_put(
            h,
            CString::new("a").unwrap().as_ptr(),
            CString::new("1").unwrap().as_ptr(),
        ));
        let _ = take(rga_store_put(
            h,
            CString::new("b").unwrap().as_ptr(),
            CString::new("2").unwrap().as_ptr(),
        ));
        let _ = take(rga_store_put(
            h,
            CString::new("c").unwrap().as_ptr(),
            CString::new("3").unwrap().as_ptr(),
        ));
        let s = take(rga_reclaim_report(h));
        let v: serde_json::Value = serde_json::from_str(&s).unwrap();
        assert_eq!(v["entries"], 3);
        assert_eq!(v["keys"], serde_json::json!(["a", "b", "c"]));
        let s = take(rga_reclaim_delete(
            h,
            CString::new(r#"["b", "ghost"]"#).unwrap().as_ptr(),
        ));
        let v: serde_json::Value = serde_json::from_str(&s).unwrap();
        assert_eq!(v["deleted"], serde_json::json!(["b"]));
        assert_eq!(v["missing"], serde_json::json!(["ghost"]));
        let s = take(rga_reclaim_trim(h, 1));
        let v: serde_json::Value = serde_json::from_str(&s).unwrap();
        assert_eq!(v["removed"], serde_json::json!(["a"]));
        assert_eq!(v["remaining"], 1);
        let s = take(rga_reclaim_trim(h, 0));
        let v: serde_json::Value = serde_json::from_str(&s).unwrap();
        assert_eq!(v["error"], "reclaim_cap_must_be_positive");
        rga_daemon_stop(h);
    }
}
