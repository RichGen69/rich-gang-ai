import 'dart:ffi';
import 'package:ffi/ffi.dart';

// Native (C) signatures and their Dart mirrors. Keep them separate:
// using one typedef for both sides is a common source of silent ABI bugs.
typedef _AbiVersionC = Uint32 Function();
typedef _AbiVersionD = int Function();
typedef _VersionC = Pointer<Utf8> Function();
typedef _VersionD = Pointer<Utf8> Function();
typedef _StartC = Pointer<Void> Function(Pointer<Utf8>);
typedef _StartD = Pointer<Void> Function(Pointer<Utf8>);
typedef _StopC = Void Function(Pointer<Void>);
typedef _StopD = void Function(Pointer<Void>);
typedef _QueryC = Pointer<Utf8> Function(
    Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>);
typedef _QueryD = Pointer<Utf8> Function(
    Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>);
typedef _SceneC = Pointer<Utf8> Function(Pointer<Void>, Pointer<Utf8>);
typedef _SceneD = Pointer<Utf8> Function(Pointer<Void>, Pointer<Utf8>);
typedef _TickC = Uint64 Function(Pointer<Void>);
typedef _TickD = int Function(Pointer<Void>);
typedef _FreeC = Void Function(Pointer<Utf8>);
typedef _FreeD = void Function(Pointer<Utf8>);
typedef _PersonasC = Pointer<Utf8> Function(Pointer<Void>);
typedef _PersonasD = Pointer<Utf8> Function(Pointer<Void>);
typedef _RememberC = Pointer<Utf8> Function(
    Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>);
typedef _RememberD = Pointer<Utf8> Function(
    Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>);
typedef _RecallC = Pointer<Utf8> Function(Pointer<Void>, Pointer<Utf8>, Uint32);
typedef _RecallD = Pointer<Utf8> Function(Pointer<Void>, Pointer<Utf8>, int);
typedef _WitnessFactsC = Pointer<Utf8> Function(Pointer<Void>, Pointer<Utf8>);
typedef _WitnessFactsD = Pointer<Utf8> Function(Pointer<Void>, Pointer<Utf8>);
typedef _WitnessStmtC = Pointer<Utf8> Function(
    Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>);
typedef _WitnessStmtD = Pointer<Utf8> Function(
    Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>);
typedef _BroadcastC = Pointer<Utf8> Function(Pointer<Void>);
typedef _BroadcastD = Pointer<Utf8> Function(Pointer<Void>);
typedef _WitnessesC = Pointer<Utf8> Function(Pointer<Void>);
typedef _WitnessesD = Pointer<Utf8> Function(Pointer<Void>);
typedef _SceneStateC = Pointer<Utf8> Function(Pointer<Void>);
typedef _SceneStateD = Pointer<Utf8> Function(Pointer<Void>);
typedef _GrammarC = Pointer<Utf8> Function();
typedef _GrammarD = Pointer<Utf8> Function();
typedef _TopologyStateC = Pointer<Utf8> Function(Pointer<Void>);
typedef _TopologyStateD = Pointer<Utf8> Function(Pointer<Void>);
typedef _TopologyReachesC = Pointer<Utf8> Function(
    Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>);
typedef _TopologyReachesD = Pointer<Utf8> Function(
    Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>);
typedef _StoreStateC = Pointer<Utf8> Function(Pointer<Void>);
typedef _StoreStateD = Pointer<Utf8> Function(Pointer<Void>);
typedef _StorePutC = Pointer<Utf8> Function(
    Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>);
typedef _StorePutD = Pointer<Utf8> Function(
    Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>);
typedef _StoreGetC = Pointer<Utf8> Function(Pointer<Void>, Pointer<Utf8>);
typedef _StoreGetD = Pointer<Utf8> Function(Pointer<Void>, Pointer<Utf8>);
typedef _StoreDeleteC = Pointer<Utf8> Function(Pointer<Void>, Pointer<Utf8>);
typedef _StoreDeleteD = Pointer<Utf8> Function(Pointer<Void>, Pointer<Utf8>);
typedef _RingStateC = Pointer<Utf8> Function(Pointer<Void>);
typedef _RingStateD = Pointer<Utf8> Function(Pointer<Void>);
typedef _RingSendC = Pointer<Utf8> Function(Pointer<Void>, Pointer<Utf8>);
typedef _RingSendD = Pointer<Utf8> Function(Pointer<Void>, Pointer<Utf8>);
typedef _RingRecvC = Pointer<Utf8> Function(Pointer<Void>);
typedef _RingRecvD = Pointer<Utf8> Function(Pointer<Void>);
typedef _SpawnStateC = Pointer<Utf8> Function(Pointer<Void>);
typedef _SpawnStateD = Pointer<Utf8> Function(Pointer<Void>);
typedef _SpawnAcquireC = Pointer<Utf8> Function(Pointer<Void>);
typedef _SpawnAcquireD = Pointer<Utf8> Function(Pointer<Void>);
typedef _SpawnReleaseC = Pointer<Utf8> Function(Pointer<Void>, Uint32);
typedef _SpawnReleaseD = Pointer<Utf8> Function(Pointer<Void>, int);
typedef _IntentStateC = Pointer<Utf8> Function(Pointer<Void>);
typedef _IntentStateD = Pointer<Utf8> Function(Pointer<Void>);
typedef _IntentEnqueueC = Pointer<Utf8> Function(Pointer<Void>, Pointer<Utf8>);
typedef _IntentEnqueueD = Pointer<Utf8> Function(Pointer<Void>, Pointer<Utf8>);
typedef _IntentDequeueC = Pointer<Utf8> Function(Pointer<Void>);
typedef _IntentDequeueD = Pointer<Utf8> Function(Pointer<Void>);
typedef _ReclaimReportC = Pointer<Utf8> Function(Pointer<Void>);
typedef _ReclaimReportD = Pointer<Utf8> Function(Pointer<Void>);
typedef _ReclaimDeleteC = Pointer<Utf8> Function(Pointer<Void>, Pointer<Utf8>);
typedef _ReclaimDeleteD = Pointer<Utf8> Function(Pointer<Void>, Pointer<Utf8>);
typedef _ReclaimTrimC = Pointer<Utf8> Function(Pointer<Void>, Uint32);
typedef _ReclaimTrimD = Pointer<Utf8> Function(Pointer<Void>, int);

/// Dart side of the Rust daemon (libdaemon.so).
///
/// Ownership: every Pointer<Utf8> returned by Rust is freed via
/// rga_string_free in a finally block, after toDartString(). Every
/// Pointer<Utf8> allocated here with toNativeUtf8() is freed with
/// malloc.free in a finally block. The rga_version() pointer is STATIC
/// and must never be freed.
class NativeBridge {
  static const int expectedAbi = 2;

  NativeBridge._() {
    _lib = DynamicLibrary.open('libdaemon.so');
    _abiVersion =
        _lib.lookupFunction<_AbiVersionC, _AbiVersionD>('rga_abi_version');
    _version = _lib.lookupFunction<_VersionC, _VersionD>('rga_version');
    _start = _lib.lookupFunction<_StartC, _StartD>('rga_daemon_start');
    _stop = _lib.lookupFunction<_StopC, _StopD>('rga_daemon_stop');
    _query = _lib.lookupFunction<_QueryC, _QueryD>('rga_agent_query');
    _scene = _lib.lookupFunction<_SceneC, _SceneD>('rga_scene_apply');
    _tick = _lib.lookupFunction<_TickC, _TickD>('rga_dream_cycle_tick');
    _free = _lib.lookupFunction<_FreeC, _FreeD>('rga_string_free');
    _personas = _lib.lookupFunction<_PersonasC, _PersonasD>('rga_personas');
    _remember = _lib.lookupFunction<_RememberC, _RememberD>('rga_remember');
    _recall = _lib.lookupFunction<_RecallC, _RecallD>('rga_recall');
    _witnessFacts =
        _lib.lookupFunction<_WitnessFactsC, _WitnessFactsD>('rga_witness_facts');
    _witnessStatement = _lib.lookupFunction<_WitnessStmtC, _WitnessStmtD>(
        'rga_witness_statement');
    _dreamBroadcast =
        _lib.lookupFunction<_BroadcastC, _BroadcastD>('rga_dream_broadcast');
    _witnesses =
        _lib.lookupFunction<_WitnessesC, _WitnessesD>('rga_witnesses');
    _sceneState =
        _lib.lookupFunction<_SceneStateC, _SceneStateD>('rga_scene_state');
    _affectGrammar =
        _lib.lookupFunction<_GrammarC, _GrammarD>('rga_affect_grammar');
    _topologyState = _lib.lookupFunction<_TopologyStateC, _TopologyStateD>(
        'rga_topology_state');
    _topologyReaches =
        _lib.lookupFunction<_TopologyReachesC, _TopologyReachesD>(
            'rga_topology_reaches');
    _storeState =
        _lib.lookupFunction<_StoreStateC, _StoreStateD>('rga_store_state');
    _storePut = _lib.lookupFunction<_StorePutC, _StorePutD>('rga_store_put');
    _storeGet = _lib.lookupFunction<_StoreGetC, _StoreGetD>('rga_store_get');
    _storeDelete =
        _lib.lookupFunction<_StoreDeleteC, _StoreDeleteD>('rga_store_delete');
    _ringState =
        _lib.lookupFunction<_RingStateC, _RingStateD>('rga_ring_state');
    _ringSend = _lib.lookupFunction<_RingSendC, _RingSendD>('rga_ring_send');
    _ringRecv = _lib.lookupFunction<_RingRecvC, _RingRecvD>('rga_ring_recv');
    _spawnState =
        _lib.lookupFunction<_SpawnStateC, _SpawnStateD>('rga_spawn_state');
    _spawnAcquire = _lib.lookupFunction<_SpawnAcquireC, _SpawnAcquireD>(
        'rga_spawn_acquire');
    _spawnRelease = _lib.lookupFunction<_SpawnReleaseC, _SpawnReleaseD>(
        'rga_spawn_release');
    _intentState =
        _lib.lookupFunction<_IntentStateC, _IntentStateD>('rga_intent_state');
    _intentEnqueue = _lib.lookupFunction<_IntentEnqueueC, _IntentEnqueueD>(
        'rga_intent_enqueue');
    _intentDequeue = _lib.lookupFunction<_IntentDequeueC, _IntentDequeueD>(
        'rga_intent_dequeue');
    _reclaimReport = _lib.lookupFunction<_ReclaimReportC, _ReclaimReportD>(
        'rga_reclaim_report');
    _reclaimDelete = _lib.lookupFunction<_ReclaimDeleteC, _ReclaimDeleteD>(
        'rga_reclaim_delete');
    _reclaimTrim =
        _lib.lookupFunction<_ReclaimTrimC, _ReclaimTrimD>('rga_reclaim_trim');

    final abi = _abiVersion();
    if (abi != expectedAbi) {
      throw StateError(
          'libdaemon.so ABI mismatch: got $abi, expected $expectedAbi. '
          'Rebuild the Rust core and restage the library (build_android.sh).');
    }
  }

  static NativeBridge? _inst;
  factory NativeBridge() => _inst ??= NativeBridge._();

  late final DynamicLibrary _lib;
  late final _AbiVersionD _abiVersion;
  late final _VersionD _version;
  late final _StartD _start;
  late final _StopD _stop;
  late final _QueryD _query;
  late final _SceneD _scene;
  late final _TickD _tick;
  late final _FreeD _free;
  late final _PersonasD _personas;
  late final _RememberD _remember;
  late final _RecallD _recall;
  late final _WitnessFactsD _witnessFacts;
  late final _WitnessStmtD _witnessStatement;
  late final _WitnessesD _witnesses;
  late final _SceneStateD _sceneState;
  late final _GrammarD _affectGrammar;
  late final _TopologyStateD _topologyState;
  late final _TopologyReachesD _topologyReaches;
  late final _StoreStateD _storeState;
  late final _StorePutD _storePut;
  late final _StoreGetD _storeGet;
  late final _StoreDeleteD _storeDelete;
  late final _RingStateD _ringState;
  late final _RingSendD _ringSend;
  late final _RingRecvD _ringRecv;
  late final _SpawnStateD _spawnState;
  late final _SpawnAcquireD _spawnAcquire;
  late final _SpawnReleaseD _spawnRelease;
  late final _IntentStateD _intentState;
  late final _IntentEnqueueD _intentEnqueue;
  late final _IntentDequeueD _intentDequeue;
  late final _ReclaimReportD _reclaimReport;
  late final _ReclaimDeleteD _reclaimDelete;
  late final _ReclaimTrimD _reclaimTrim;
  late final _BroadcastD _dreamBroadcast;

  Pointer<Void>? _handle;
  bool get isUp => _handle != null && _handle!.address != 0;

  /// Static string owned by Rust - never free it.
  String get daemonVersion => _version().toDartString();

  /// Idempotent.
  void boot({String config = '{}'}) {
    if (isUp) return;
    final cfg = config.toNativeUtf8();
    try {
      _handle = _start(cfg);
    } finally {
      malloc.free(cfg);
    }
    if (!isUp) throw StateError('rga_daemon_start returned null');
    // Rust also logs "[RICHARD] daemon online" under tag RGA.Rust, which is
    // what `adb logcat -s RGA.Rust` shows for Milestone 1.
  }

  String query(String persona, String input) {
    if (!isUp) throw StateError('daemon not booted');
    final p = persona.toNativeUtf8();
    final q = input.toNativeUtf8();
    try {
      final r = _query(_handle!, p, q);
      if (r == nullptr) return '{"error":"null_response"}';
      try {
        return r.toDartString();
      } finally {
        _free(r);
      }
    } finally {
      malloc.free(p);
      malloc.free(q);
    }
  }

  String sceneApply(String proposalJson) {
    if (!isUp) throw StateError('daemon not booted');
    final j = proposalJson.toNativeUtf8();
    try {
      final r = _scene(_handle!, j);
      if (r == nullptr) return '{"error":"null_response"}';
      try {
        return r.toDartString();
      } finally {
        _free(r);
      }
    } finally {
      malloc.free(j);
    }
  }

  int tick() => isUp ? _tick(_handle!) : 0;

  /// Shared helper for the v2 string-returning calls: allocates inputs,
  /// calls Rust, copies the result, frees BOTH sides in finally blocks.
  String _call(List<Pointer<Utf8>> args,
      Pointer<Utf8> Function(List<Pointer<Utf8>> args) fn) {
    try {
      final r = fn(args);
      if (r == nullptr) return '{"error":"null_response"}';
      try {
        return r.toDartString();
      } finally {
        _free(r);
      }
    } finally {
      for (final a in args) {
        malloc.free(a);
      }
    }
  }

  /// `{"personas":[...]}` from Rust — the roster's single source of truth.
  String personas() {
    if (!isUp) throw StateError('daemon not booted');
    final r = _personas(_handle!);
    if (r == nullptr) return '{"error":"null_response"}';
    try {
      return r.toDartString();
    } finally {
      _free(r);
    }
  }

  /// Store a memory in the local vector store. Returns the Rust JSON doc.
  String remember(String id, String text) {
    if (!isUp) throw StateError('daemon not booted');
    final a = id.toNativeUtf8();
    final b = text.toNativeUtf8();
    return _call([a, b], (_) => _remember(_handle!, a, b));
  }

  /// Recall memories with the highest lexical (token-overlap) score
  /// against [query] — not semantic similarity; no embedding model is
  /// bundled. Returns the Rust JSON doc.
  String recall(String query, {int k = 5}) {
    if (!isUp) throw StateError('daemon not booted');
    final a = query.toNativeUtf8();
    try {
      final r = _recall(_handle!, a, k);
      if (r == nullptr) return '{"error":"null_response"}';
      try {
        return r.toDartString();
      } finally {
        _free(r);
      }
    } finally {
      malloc.free(a);
    }
  }

  /// Names of the witnesses in the loaded scene (empty when no scene
  /// data was supplied in the daemon config). Returns the Rust JSON doc.
  String witnesses() {
    if (!isUp) throw StateError('daemon not booted');
    final r = _witnesses(_handle!);
    if (r == nullptr) return '{"error":"null_response"}';
    try {
      return r.toDartString();
    } finally {
      _free(r);
    }
  }

  /// Facts one interrogation witness knows. Returns the Rust JSON doc.
  String witnessFacts(String witness) {
    if (!isUp) throw StateError('daemon not booted');
    final a = witness.toNativeUtf8();
    return _call([a], (_) => _witnessFacts(_handle!, a));
  }

  /// The in-play statement for one fact (lie version when permitted).
  String witnessStatement(String witness, String factId) {
    if (!isUp) throw StateError('daemon not booted');
    final a = witness.toNativeUtf8();
    final b = factId.toNativeUtf8();
    return _call([a, b], (_) => _witnessStatement(_handle!, a, b));
  }

  /// Produce + store a text-only dream broadcast. Returns the Rust JSON doc.
  String dreamBroadcast() {
    if (!isUp) throw StateError('daemon not booted');
    final r = _dreamBroadcast(_handle!);
    if (r == nullptr) return '{"error":"null_response"}';
    try {
      return r.toDartString();
    } finally {
      _free(r);
    }
  }

  /// Scene snapshot JSON from Rust: accepted-frame count, last beat,
  /// and the last accepted Delta (or `"last_delta": null`). The
  /// Performance Director's only input.
  String sceneState() {
    if (!isUp) throw StateError('daemon not booted');
    final r = _sceneState(_handle!);
    if (r == nullptr) return '{"error":"null_response"}';
    try {
      return r.toDartString();
    } finally {
      _free(r);
    }
  }

  /// The GBNF grammar for the AffectFrame schema (plain text). Static
  /// in Rust, so this works without a booted daemon; the returned
  /// string is still Rust-allocated and freed here per contract.
  String affectGrammar() {
    final r = _affectGrammar();
    if (r == nullptr) return '';
    try {
      return r.toDartString();
    } finally {
      _free(r);
    }
  }

  /// Causal topology snapshot from Rust (v5 Tier 3, petgraph):
  /// `{"nodes":N,"edges":M,"order":[...]}` from the daemon config's
  /// "causal_links" — empty counts/order when none were supplied, and
  /// a `causal_cycle_detected` error doc on a cyclic graph. Returns
  /// the Rust JSON doc.
  String topologyState() {
    if (!isUp) throw StateError('daemon not booted');
    final r = _topologyState(_handle!);
    if (r == nullptr) return '{"error":"null_response"}';
    try {
      return r.toDartString();
    } finally {
      _free(r);
    }
  }

  /// Multi-hop causal reachability in the Rust topology:
  /// `{"from":...,"to":...,"reaches":bool}`. Unknown names return
  /// reaches:false. Returns the Rust JSON doc.
  String topologyReaches(String from, String to) {
    if (!isUp) throw StateError('daemon not booted');
    final a = from.toNativeUtf8();
    final b = to.toNativeUtf8();
    return _call([a, b], (_) => _topologyReaches(_handle!, a, b));
  }

  /// Persistent store snapshot from Rust (v5 Tier 2, rusqlite):
  /// `{"persistent":bool,"journal_mode":...,"entries":N,"sqlite_version":...}`.
  /// `persistent` is false when the daemon config named no
  /// "store_path" — the store is then in-memory for this session
  /// only. Returns the Rust JSON doc.
  String storeState() {
    if (!isUp) throw StateError('daemon not booted');
    final r = _storeState(_handle!);
    if (r == nullptr) return '{"error":"null_response"}';
    try {
      return r.toDartString();
    } finally {
      _free(r);
    }
  }

  /// Store one key/value pair in the Rust SQLite store:
  /// `{"ok":true,"key":...}`. Returns the Rust JSON doc.
  String storePut(String key, String value) {
    if (!isUp) throw StateError('daemon not booted');
    final a = key.toNativeUtf8();
    final b = value.toNativeUtf8();
    return _call([a, b], (_) => _storePut(_handle!, a, b));
  }

  /// Read one key from the Rust SQLite store:
  /// `{"key":...,"found":true,"value":...}`, or
  /// `{"key":...,"found":false}` when the key does not exist.
  /// Returns the Rust JSON doc.
  String storeGet(String key) {
    if (!isUp) throw StateError('daemon not booted');
    final a = key.toNativeUtf8();
    return _call([a], (_) => _storeGet(_handle!, a));
  }

  /// Delete one key from the Rust SQLite store:
  /// `{"key":...,"existed":bool}`. Returns the Rust JSON doc.
  String storeDelete(String key) {
    if (!isUp) throw StateError('daemon not booted');
    final a = key.toNativeUtf8();
    return _call([a], (_) => _storeDelete(_handle!, a));
  }

  /// Memory-mapped ring snapshot from Rust (v5 Tier 5, memmap2):
  /// `{"enabled":bool,"capacity":N,"head":N,"tail":N,
  /// "pending_bytes":N,"pending_messages":N}`. `enabled` is false
  /// when the daemon config named no "ring_path" — there is then no
  /// ring at all. Returns the Rust JSON doc.
  String ringState() {
    if (!isUp) throw StateError('daemon not booted');
    final r = _ringState(_handle!);
    if (r == nullptr) return '{"error":"null_response"}';
    try {
      return r.toDartString();
    } finally {
      _free(r);
    }
  }

  /// Send one message into the Rust memory-mapped ring:
  /// `{"ok":true,"bytes":N}`, or `{"error":"ring_full"}` when the
  /// ring is full (the message is NOT queued), or
  /// `{"error":"ring_disabled"}` when no ring is configured.
  /// Returns the Rust JSON doc.
  String ringSend(String payload) {
    if (!isUp) throw StateError('daemon not booted');
    final a = payload.toNativeUtf8();
    return _call([a], (_) => _ringSend(_handle!, a));
  }

  /// Receive the oldest pending ring message from Rust:
  /// `{"found":true,"message":...}`, or `{"found":false}` when the
  /// ring is empty. Returns the Rust JSON doc.
  String ringRecv() {
    if (!isUp) throw StateError('daemon not booted');
    final r = _ringRecv(_handle!);
    if (r == nullptr) return '{"error":"null_response"}';
    try {
      return r.toDartString();
    } finally {
      _free(r);
    }
  }

  /// Bounded spawn-budget state from Rust (Execution Matrix
  /// reality, 2026-10-31): `{"max":3,"held":N,"free":[slots]}`.
  /// Returns the Rust JSON doc.
  String spawnState() {
    if (!isUp) throw StateError('daemon not booted');
    final r = _spawnState(_handle!);
    if (r == nullptr) return '{"error":"null_response"}';
    try {
      return r.toDartString();
    } finally {
      _free(r);
    }
  }

  /// Acquire one spawn-budget slot: `{"ok":true,"slot":N}`, or
  /// `{"error":"spawn_budget_exhausted"}` past 3 concurrent tasks
  /// (the task is never silently queued). Returns the Rust JSON doc.
  String spawnAcquire() {
    if (!isUp) throw StateError('daemon not booted');
    final r = _spawnAcquire(_handle!);
    if (r == nullptr) return '{"error":"null_response"}';
    try {
      return r.toDartString();
    } finally {
      _free(r);
    }
  }

  /// Release a spawn-budget slot: `{"ok":true,"slot":N}`, or an
  /// explicit error for an invalid or not-held slot.
  /// Returns the Rust JSON doc.
  String spawnRelease(int slot) {
    if (!isUp) throw StateError('daemon not booted');
    final r = _spawnRelease(_handle!, slot);
    if (r == nullptr) return '{"error":"null_response"}';
    try {
      return r.toDartString();
    } finally {
      _free(r);
    }
  }

  /// Bounded intent-queue state from Rust (Execution Matrix
  /// reality, 2026-10-31): `{"depth":N,"capacity":N,"full":bool}`.
  /// The queue is the ingestion stage only; arbitration is the
  /// Roundtable + Danny chain. Returns the Rust JSON doc.
  String intentState() {
    if (!isUp) throw StateError('daemon not booted');
    final r = _intentState(_handle!);
    if (r == nullptr) return '{"error":"null_response"}';
    try {
      return r.toDartString();
    } finally {
      _free(r);
    }
  }

  /// Enqueue one intent: `{"ok":true,"depth":N}`, or
  /// `{"error":"intent_queue_full"}` when at capacity (the intent
  /// is never stored and never silently dropped).
  /// Returns the Rust JSON doc.
  String intentEnqueue(String intent) {
    if (!isUp) throw StateError('daemon not booted');
    final a = intent.toNativeUtf8();
    return _call([a], (_) => _intentEnqueue(_handle!, a));
  }

  /// Dequeue the oldest intent: `{"found":true,"intent":...}`, or
  /// `{"found":false}` when the queue is empty.
  /// Returns the Rust JSON doc.
  String intentDequeue() {
    if (!isUp) throw StateError('daemon not booted');
    final r = _intentDequeue(_handle!);
    if (r == nullptr) return '{"error":"null_response"}';
    try {
      return r.toDartString();
    } finally {
      _free(r);
    }
  }

  /// Bounded store sweep report from Rust (Execution Matrix
  /// reality, 2026-10-31): `{"entries":N,"persistent":bool,
  /// "journal_mode":...,"keys":[...]}` from real SQLite state.
  /// No time-based expiry exists: the kv schema has no timestamps.
  /// Returns the Rust JSON doc.
  String reclaimReport() {
    if (!isUp) throw StateError('daemon not booted');
    final r = _reclaimReport(_handle!);
    if (r == nullptr) return '{"error":"null_response"}';
    try {
      return r.toDartString();
    } finally {
      _free(r);
    }
  }

  /// Delete exactly the named keys (JSON array of key strings):
  /// `{"deleted":[...],"missing":[...]}`. Nothing else is touched.
  /// Returns the Rust JSON doc.
  String reclaimDelete(String keysJson) {
    if (!isUp) throw StateError('daemon not booted');
    final a = keysJson.toNativeUtf8();
    return _call([a], (_) => _reclaimDelete(_handle!, a));
  }

  /// Enforce a caller-supplied cap (must be > 0) by deleting
  /// oldest-first (rowid order) beyond it:
  /// `{"removed":[...],"remaining":N}`.
  /// Returns the Rust JSON doc.
  String reclaimTrim(int cap) {
    if (!isUp) throw StateError('daemon not booted');
    final r = _reclaimTrim(_handle!, cap);
    if (r == nullptr) return '{"error":"null_response"}';
    try {
      return r.toDartString();
    } finally {
      _free(r);
    }
  }

  /// Idempotent.
  void shutdown() {
    if (!isUp) return;
    _stop(_handle!);
    _handle = null;
  }
}
