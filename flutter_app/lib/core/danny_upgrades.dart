import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'affect_engine.dart';
import 'character.dart';

/// Danny's SELF-UPGRADE loop — bounded, guardrailed, accountable.
///
/// Richard's terms: "enable Danny to upgrade himself — with
/// guardrails though", plus responsibility made mechanical. This
/// module is the whole mechanism, and its limits are the point:
///
/// WHAT DANNY CAN CHANGE (the allowlist, nothing else):
///  - baseline_pleasure / baseline_arousal / baseline_dominance,
///    each within ±0.15 of the AUTHORED value in characters.json;
///  - talkativeness, within ±0.10 of authored (and 0..1);
///  - volatility, within ±0.10 of authored (and 0..1);
///  - self_note: his own short self-description (≤280 chars).
/// Learned interests, reflections and open loops are NOT here —
/// they already live in the self-model (self_model.dart) and are
/// written by its own paths.
///
/// WHAT HE CAN NEVER CHANGE through this path: his moral core,
/// his guardrails, his core/personality/speech, his voice casting,
/// his portrait, his status, his identity — and nothing about any
/// other character. Attempts are rejected with an explicit
/// [DannyUpgradeException] AND written to the accountability log:
/// a refused attempt is still on his record.
///
/// EVERY ACCEPTED CHANGE is a versioned snapshot (full state
/// before/after, reason, timestamp) appended to the accountability
/// log, and rollback restores an earlier snapshot by APPENDING a
/// rollback entry — history is never rewritten. The log is
/// append-only from Danny's side: this class exposes no edit or
/// delete operation at all, which the tests assert.
///
/// THE DRIVER: DeepDream's reflection for Danny (deep_dream.dart)
/// calls [tuneFromReflection], which nudges his PAD baselines 10%
/// of the way toward his current affect, inside the bands. That is
/// parameter-level self-tuning from his dream cycle — it is NOT
/// model retraining, NOT code self-modification, and the docs say
/// so. A kill switch ([enabled]) disables the whole loop; it
/// defaults ON because the guardrail tests in
/// test/danny_flagship_test.dart all pass — if they ever fail,
/// the honest move is to flip the default and say why.
///
/// Persistence: SharedPreferences, the same on-device path as the
/// mind store ('danny_upgrades_v1'). The daemon's rusqlite store
/// is NOT used: the shipped daemon_config names no store_path, so
/// that store is an in-memory session store today — claiming
/// Danny's state rides it would be false.
class DannyUpgradeException implements Exception {
  DannyUpgradeException(this.message);
  final String message;
  @override
  String toString() => 'DannyUpgradeException: $message';
}

enum AccountabilityKind { upgrade, rollback, rejection, killSwitch, selfNote }

class AccountabilityEntry {
  const AccountabilityEntry({
    required this.seq,
    required this.at,
    required this.kind,
    required this.detail,
    required this.reason,
    this.snapshotVersion,
  });
  final int seq;
  final DateTime at;
  final AccountabilityKind kind;

  /// What happened, in data: 'baseline_dominance: 0.7 -> 0.72',
  /// or for a rejection, the attempted write that was refused.
  final String detail;

  /// Why — for upgrades, the reflection/dream reason that drove
  /// it; for rejections, the guardrail that fired.
  final String reason;

  /// The tuning snapshot version this entry produced (upgrades
  /// and rollbacks), so every trophy on the shelf points at the
  /// exact state it created.
  final int? snapshotVersion;

  Map<String, dynamic> toJson() => {
        'seq': seq,
        'at': at.toIso8601String(),
        'kind': kind.name,
        'detail': detail,
        'reason': reason,
        'snapshot_version': snapshotVersion,
      };

  factory AccountabilityEntry.fromJson(Map<String, dynamic> j) =>
      AccountabilityEntry(
        seq: (j['seq'] as num).toInt(),
        at: DateTime.parse(j['at'] as String),
        kind: AccountabilityKind.values.byName(j['kind'] as String),
        detail: j['detail'] as String,
        reason: j['reason'] as String,
        snapshotVersion: (j['snapshot_version'] as num?)?.toInt(),
      );
}

/// Danny's current tuned parameters. Version 0 = the authored
/// definition values, untouched.
class DannyTuning {
  DannyTuning.fromAuthored(CharacterDef def)
      : pleasure = def.baselinePleasure,
        arousal = def.baselineArousal,
        dominance = def.baselineDominance,
        talkativeness = def.talkativeness,
        volatility = def.volatility,
        selfNote = '',
        version = 0;

  DannyTuning._({
    required this.pleasure,
    required this.arousal,
    required this.dominance,
    required this.talkativeness,
    required this.volatility,
    required this.selfNote,
    required this.version,
  });

  double pleasure;
  double arousal;
  double dominance;
  double talkativeness;
  double volatility;
  String selfNote;
  int version;

  Pad get baselinePad => Pad(pleasure, arousal, dominance);

  DannyTuning copyAtVersion(int v) => DannyTuning._(
        pleasure: pleasure,
        arousal: arousal,
        dominance: dominance,
        talkativeness: talkativeness,
        volatility: volatility,
        selfNote: selfNote,
        version: v,
      );

  Map<String, dynamic> toJson() => {
        'pleasure': pleasure,
        'arousal': arousal,
        'dominance': dominance,
        'talkativeness': talkativeness,
        'volatility': volatility,
        'self_note': selfNote,
        'version': version,
      };

  factory DannyTuning.fromJson(Map<String, dynamic> j) => DannyTuning._(
        pleasure: (j['pleasure'] as num).toDouble(),
        arousal: (j['arousal'] as num).toDouble(),
        dominance: (j['dominance'] as num).toDouble(),
        talkativeness: (j['talkativeness'] as num).toDouble(),
        volatility: (j['volatility'] as num).toDouble(),
        selfNote: j['self_note'] as String? ?? '',
        version: (j['version'] as num).toInt(),
      );
}

class DannyUpgradeController {
  DannyUpgradeController(this.def) : state = DannyTuning.fromAuthored(def) {
    if (def.id != 'danny') {
      throw ArgumentError(
          'the self-upgrade loop exists for Danny only (got ${def.id})');
    }
    _snapshots[0] = state.copyAtVersion(0);
  }

  final CharacterDef def;
  DannyTuning state;

  /// The kill switch. Persisted. See the class doc for why the
  /// default is ON.
  bool enabled = true;

  final List<AccountabilityEntry> _log = [];
  final Map<int, DannyTuning> _snapshots = {};

  /// The accountability record — append-only. Callers get an
  /// unmodifiable view; this class deliberately has NO method
  /// that edits or removes an entry, and rollback appends rather
  /// than rewrites. Richard reviews the record; Danny cannot
  /// clean his own shelf.
  List<AccountabilityEntry> get log => List.unmodifiable(_log);

  /// THE TROPHY SHELF: the verified self-upgrades — every entry
  /// here is backed by the snapshot it created and the reason it
  /// recorded. Nothing reaches the shelf without both.
  List<AccountabilityEntry> get trophyShelf => [
        for (final e in _log)
          if (e.kind == AccountabilityKind.upgrade && e.snapshotVersion != null)
            e,
      ];

  static const padBand = 0.15;
  static const rateBand = 0.10;
  static const selfNoteMax = 280;

  /// The complete allowlist. Anything not named here — including
  /// 'moral_core', 'guardrails', 'voice', 'core', 'status',
  /// 'portrait' and every other character's parameters — is
  /// rejected, by construction: there is no code path that writes
  /// them.
  static const allowlist = {
    'baseline_pleasure',
    'baseline_arousal',
    'baseline_dominance',
    'talkativeness',
    'volatility',
    'self_note',
  };

  (double, double) _boundsFor(String param) {
    switch (param) {
      case 'baseline_pleasure':
        return (def.baselinePleasure - padBand, def.baselinePleasure + padBand);
      case 'baseline_arousal':
        return (def.baselineArousal - padBand, def.baselineArousal + padBand);
      case 'baseline_dominance':
        return (
          def.baselineDominance - padBand,
          def.baselineDominance + padBand
        );
      case 'talkativeness':
        return (
          (def.talkativeness - rateBand).clamp(0.0, 1.0),
          (def.talkativeness + rateBand).clamp(0.0, 1.0)
        );
      case 'volatility':
        return (
          (def.volatility - rateBand).clamp(0.0, 1.0),
          (def.volatility + rateBand).clamp(0.0, 1.0)
        );
      default:
        throw DannyUpgradeException('"$param" is not in the allowlist');
    }
  }

  double _valueOf(String param) => switch (param) {
        'baseline_pleasure' => state.pleasure,
        'baseline_arousal' => state.arousal,
        'baseline_dominance' => state.dominance,
        'talkativeness' => state.talkativeness,
        'volatility' => state.volatility,
        _ => throw DannyUpgradeException('"$param" is not numeric'),
      };

  void _setValue(String param, double v) {
    switch (param) {
      case 'baseline_pleasure':
        state.pleasure = v;
      case 'baseline_arousal':
        state.arousal = v;
      case 'baseline_dominance':
        state.dominance = v;
      case 'talkativeness':
        state.talkativeness = v;
      case 'volatility':
        state.volatility = v;
    }
  }

  void _record(AccountabilityKind kind, String detail, String reason,
      {int? snapshotVersion}) {
    _log.add(AccountabilityEntry(
      seq: _log.length,
      at: DateTime.now(),
      kind: kind,
      detail: detail,
      reason: reason,
      snapshotVersion: snapshotVersion,
    ));
  }

  Never _reject(String attempted, String guardrail) {
    _record(AccountabilityKind.rejection, attempted, guardrail);
    throw DannyUpgradeException(guardrail);
  }

  /// Apply one allowlisted change. Out-of-band values are
  /// REJECTED (not silently clamped — a tuning he didn't ask for
  /// is not a tuning he made), and every rejection is logged
  /// before the exception propagates.
  void applyChange(String param, Object value, {required String reason}) {
    if (!enabled) {
      _reject('$param := $value',
          'self-upgrade is disabled by the kill switch');
    }
    if (!allowlist.contains(param)) {
      _reject('$param := $value',
          'guardrail: "$param" is not in the self-upgrade allowlist');
    }
    if (param == 'self_note') {
      final note = value.toString();
      if (note.length > selfNoteMax) {
        _reject('self_note (${note.length} chars)',
            'guardrail: self_note is bounded to $selfNoteMax characters');
      }
      final from = state.selfNote;
      state = state.copyAtVersion(state.version + 1)..selfNote = note;
      _snapshots[state.version] = state.copyAtVersion(state.version);
      _record(AccountabilityKind.selfNote, 'self_note: "$from" -> "$note"',
          reason,
          snapshotVersion: state.version);
      return;
    }
    if (value is! num) {
      _reject('$param := $value',
          'guardrail: $param takes a numeric value, got ${value.runtimeType}');
    }
    final v = value.toDouble();
    final (lo, hi) = _boundsFor(param);
    if (v < lo || v > hi) {
      _reject('$param := $v',
          'guardrail: $param must stay within [$lo, $hi] '
          '(authored ± band); $v is outside');
    }
    final from = _valueOf(param);
    if (v == from) return; // no-op: no snapshot, no shelf entry
    state = state.copyAtVersion(state.version + 1);
    _setValue(param, v);
    _snapshots[state.version] = state.copyAtVersion(state.version);
    _record(AccountabilityKind.upgrade, '$param: $from -> $v', reason,
        snapshotVersion: state.version);
  }

  /// Restore an earlier snapshot. Appends a rollback entry — the
  /// upgrades being rolled back STAY on the record (that is what
  /// makes it a record). Unknown versions are rejected and logged.
  void rollback(int toVersion, {required String reason}) {
    final target = _snapshots[toVersion];
    if (target == null) {
      _reject('rollback to v$toVersion',
          'guardrail: no snapshot exists at version $toVersion');
    }
    state = target.copyAtVersion(state.version + 1);
    _snapshots[state.version] = state.copyAtVersion(state.version);
    _record(AccountabilityKind.rollback,
        'state restored to snapshot v$toVersion', reason,
        snapshotVersion: state.version);
  }

  void setEnabled(bool on, {required String reason}) {
    enabled = on;
    _record(AccountabilityKind.killSwitch,
        'self-upgrade ${on ? 'ENABLED' : 'DISABLED'}', reason);
  }

  /// The dream-cycle driver: nudge each PAD baseline 10% of the
  /// way toward Danny's current affect, inside the bands. Returns
  /// true when a real change was snapshotted; when his affect
  /// already sits on his baselines, nothing is written and no
  /// upgrade is claimed.
  bool tuneFromReflection({
    required Pad currentAffect,
    required String reason,
  }) {
    if (!enabled) return false;
    final targets = <String, double>{
      'baseline_pleasure': state.pleasure +
          (currentAffect.pleasure - state.pleasure) * 0.10,
      'baseline_arousal':
          state.arousal + (currentAffect.arousal - state.arousal) * 0.10,
      'baseline_dominance': state.dominance +
          (currentAffect.dominance - state.dominance) * 0.10,
    };
    var changed = false;
    targets.forEach((param, target) {
      final (lo, hi) = _boundsFor(param);
      final clamped = target.clamp(lo, hi).toDouble();
      if ((clamped - _valueOf(param)).abs() >= 0.005) {
        applyChange(param, clamped,
            reason: 'dream/reflection tuning: $reason');
        changed = true;
      }
    });
    return changed;
  }

  /// Push the tuned values into the live affect engine (boot and
  /// after a dream tuning pass), so the tuning is behaviour, not
  /// bookkeeping.
  void applyToAffect(AffectState affect) {
    if (state.version == 0) return;
    affect.tunedBaseline = state.baselinePad;
    affect.tunedTalkativeness = state.talkativeness;
    affect.tunedVolatility = state.volatility;
  }

  // ---- persistence (SharedPreferences, the mind-store path) ----

  static const _key = 'danny_upgrades_v1';
  static DannyUpgradeController? instance;

  static Future<DannyUpgradeController> boot(CharacterDef def) async {
    final c = DannyUpgradeController(def);
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null) c._restore(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // Unreadable store = authored state, empty record; the
      // controller claims no history it could not read.
    }
    instance = c;
    return c;
  }

  void _restore(Map<String, dynamic> j) {
    final s = j['state'];
    if (s is Map<String, dynamic>) state = DannyTuning.fromJson(s);
    enabled = j['enabled'] as bool? ?? true;
    final snaps = j['snapshots'];
    if (snaps is Map<String, dynamic>) {
      snaps.forEach((k, v) {
        if (v is Map<String, dynamic>) {
          _snapshots[int.parse(k)] = DannyTuning.fromJson(v);
        }
      });
    }
    _snapshots.putIfAbsent(0, () => DannyTuning.fromAuthored(def));
    final log = j['log'];
    if (log is List) {
      for (final raw in log) {
        if (raw is Map<String, dynamic>) {
          try {
            _log.add(AccountabilityEntry.fromJson(raw));
          } catch (_) {
            // A corrupt entry is dropped rather than rewritten —
            // the record never fabricates its own history.
          }
        }
      }
    }
  }

  Map<String, dynamic> toJson() => {
        'state': state.toJson(),
        'enabled': enabled,
        'snapshots': {
          for (final e in _snapshots.entries) '${e.key}': e.value.toJson(),
        },
        'log': [for (final e in _log) e.toJson()],
      };

  Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(toJson()));
    } catch (_) {
      // Best-effort like the mind store; no save is ever claimed
      // that did not happen — the next change retries it.
    }
  }
}
