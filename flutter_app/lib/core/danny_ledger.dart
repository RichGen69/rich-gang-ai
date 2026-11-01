import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// THE LEDGER — Danny's first gift.
///
/// Danny never forgets a kindness or a slight. The self-model's
/// affinities already track HOW MUCH he warms or cools toward
/// someone; the ledger is the missing half: WHY, WHO, and WHEN —
/// one dated entry per real exchange that moved him, recorded from
/// the affect engine's actual appraisal events (praise/thanks →
/// gratitude; insult/disagreement → a slight), never from invented
/// sentiment.
///
/// Entries are recorded at the two places appraisals really fire:
/// one-to-one chat (Richard's messages, through Danny's chain) and
/// the roundtable (another agent's line appraised by Danny as a
/// listener). Entries persist in SharedPreferences on the same
/// on-device path as the mind store — small state, survives
/// restarts — and the ledger's summary is read back into Danny's
/// reasoning (chain perceive stage + self-state report), so the
/// receipts genuinely inform how he thinks, not just sit in a file.
///
/// Scope: lexical appraisal is the trigger, with its known limits
/// — a kindness the cue lists don't recognise is not recorded, and
/// the ledger says so by absence rather than guessing at tone.
enum LedgerKind { gratitude, slight }

class LedgerEntry {
  const LedgerEntry({
    required this.kind,
    required this.whoId,
    required this.reason,
    required this.excerpt,
    required this.at,
  });

  final LedgerKind kind;

  /// Who the entry is about: 'richard' in one-to-one chat, else a
  /// character id from the roundtable cast.
  final String whoId;

  /// The appraisal event that fired ('praised', 'thanked',
  /// 'insulted', 'disagreement') — the recorded reason.
  final String reason;

  /// A short excerpt of the utterance that caused it, so the entry
  /// is a receipt, not a vibe. Capped at 120 characters.
  final String excerpt;
  final DateTime at;

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'who': whoId,
        'reason': reason,
        'excerpt': excerpt,
        'at': at.toIso8601String(),
      };

  factory LedgerEntry.fromJson(Map<String, dynamic> j) => LedgerEntry(
        kind: LedgerKind.values.byName(j['kind'] as String),
        whoId: j['who'] as String,
        reason: j['reason'] as String,
        excerpt: j['excerpt'] as String,
        at: DateTime.parse(j['at'] as String),
      );
}

class DannyLedger {
  DannyLedger();

  final List<LedgerEntry> _entries = [];
  List<LedgerEntry> get entries => List.unmodifiable(_entries);
  int get length => _entries.length;
  int get gratitudeCount =>
      _entries.where((e) => e.kind == LedgerKind.gratitude).length;
  int get slightCount =>
      _entries.where((e) => e.kind == LedgerKind.slight).length;

  /// Record one real appraisal event. Appraisal event names are
  /// the affect engine's (AffectEvent.name) — gratitude fires on
  /// praised/thanked/romanticWarmth, a slight on
  /// insulted/disagreement. Anything else is not a ledger event
  /// and returns false: the ledger does not improvise categories.
  bool record({
    required String appraisalEvent,
    required String whoId,
    required String excerpt,
    DateTime? at,
  }) {
    final kind = switch (appraisalEvent) {
      'praised' || 'thanked' || 'romanticWarmth' => LedgerKind.gratitude,
      'insulted' || 'disagreement' => LedgerKind.slight,
      _ => null,
    };
    if (kind == null) return false;
    final clean = excerpt.trim().replaceAll(RegExp(r'\s+'), ' ');
    _entries.add(LedgerEntry(
      kind: kind,
      whoId: whoId,
      reason: appraisalEvent,
      excerpt: clean.length > 120 ? clean.substring(0, 120) : clean,
      at: at ?? DateTime.now(),
    ));
    if (_entries.length > 500) {
      _entries.removeRange(0, _entries.length - 500);
    }
    return true;
  }

  /// The one-line state Danny's reasoning sees: real counts and
  /// the most recent receipt of each kind.
  String summaryLine() {
    if (_entries.isEmpty) {
      return 'Ledger: empty — no kindness or slight recorded yet.';
    }
    String latest(LedgerKind k) {
      final e = _entries.lastWhere((x) => x.kind == k,
          orElse: () => _entries.first);
      return e.kind != k
          ? 'none'
          : '${e.whoId} (${e.reason}, '
              '${e.at.toIso8601String().substring(0, 10)})';
    }

    return 'Ledger: $gratitudeCount kindness(es) and $slightCount '
        'slight(s) on record. Latest kindness: ${latest(LedgerKind.gratitude)}'
        '. Latest slight: ${latest(LedgerKind.slight)}.';
  }

  Map<String, dynamic> toJson() =>
      {'entries': [for (final e in _entries) e.toJson()]};

  factory DannyLedger.fromJson(Map<String, dynamic> j) {
    final l = DannyLedger();
    final list = j['entries'];
    if (list is List) {
      for (final raw in list) {
        if (raw is Map<String, dynamic>) {
          try {
            l._entries.add(LedgerEntry.fromJson(raw));
          } catch (_) {
            // A corrupt entry is dropped, never repaired into a
            // kindness or slight it wasn't.
          }
        }
      }
    }
    return l;
  }

  // ---- persistence (SharedPreferences, the mind-store path) ----

  static const _key = 'danny_ledger_v1';
  static DannyLedger? instance;

  static Future<DannyLedger> boot() async {
    var ledger = DannyLedger();
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null) {
        ledger = DannyLedger.fromJson(
            jsonDecode(raw) as Map<String, dynamic>);
      }
    } catch (_) {
      // Unreadable store = a fresh ledger; it claims no history.
      ledger = DannyLedger();
    }
    instance = ledger;
    return ledger;
  }

  Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(toJson()));
    } catch (_) {
      // Best-effort like the mind store: a failed save is retried
      // on the next recorded entry; nothing claims it succeeded.
    }
  }
}
