import 'dart:convert';

/// Builds the daemon's runtime configuration (P6).
///
/// The bundled asset (`assets/daemon_config.json`) is the shared
/// config SOURCE: personas (and Richard's scene facts, when he
/// supplies them) live there, and both daemon handles read it —
/// the Dart/UI handle directly, the Kotlin dream-cycle handle via
/// the same asset (see DreamCycleService).
///
/// The Dart handle is the CANONICAL OWNER of file-backed daemon
/// state. At boot the app extends the asset config with a
/// `store_path` inside the app-private support directory, so the
/// rusqlite store is durable across launches instead of
/// session-only. The Kotlin handle deliberately strips `store_path`
/// / `ring_path` from its copy: it is a tick-only handle and must
/// never become a second writer to the store or the ring.
///
/// No `ring_path` is set here: the ring has no named first workload
/// yet, and a workload-less ring stays disabled (recorded in
/// `docs/FLAGSHIP_SWEEP_2026-10-23.md`).
class DaemonConfig {
  DaemonConfig._();

  static const String storeDirectoryName = 'rich_gang_ai';
  static const String storeFileName = 'daemon_store.sqlite3';

  /// Keys of the runtime-provenance record the app writes to the
  /// store at boot — the store's first named workload: proof, on
  /// every launch, of whether the durable store is really the one
  /// serving, and which runtime-config schema booted it.
  static const String provenanceSchemaKey = 'runtime.config_schema';
  static const String provenanceBootKey = 'runtime.last_boot_at';
  static const String provenanceSchemaVersion = '1';

  static String storePathForSupportDir(String supportDir) =>
      '$supportDir/$storeDirectoryName/$storeFileName';

  /// Return [rawConfig] (the asset JSON object) with `store_path`
  /// set to [storePath]. Throws a [FormatException] when the asset
  /// is not a JSON object — a malformed shipped config must fail
  /// loudly here, not degrade into a silently different daemon.
  static String withStorePath(String rawConfig, String storePath) {
    final Object? decoded;
    try {
      decoded = jsonDecode(rawConfig);
    } on FormatException {
      throw const FormatException('daemon config asset is not valid JSON');
    }
    if (decoded is! Map) {
      throw const FormatException('daemon config asset is not a JSON object');
    }
    final map = Map<String, dynamic>.from(decoded);
    map['store_path'] = storePath;
    return jsonEncode(map);
  }
}
