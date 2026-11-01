import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'danny_discernment.dart';

/// THE LIE DETECTOR (Richard's name for it, 2026-10-23) — an
/// app-level statement-checking instrument that generalizes
/// Danny's discernment engine (danny_discernment.dart) from a
/// per-message prompt pass into a standing service with intake,
/// a persistent record, and a per-speaker credibility ledger.
///
/// WHAT IT DOES, exactly — three checks per claim, all
/// deterministic, all lexical (the same tokenizer, negation set
/// and number extraction as discernment; no second engine):
///
///  a. FACT CHECK against the daemon's witness fact table (the
///     scene data Richard supplies in daemon_config.json, read
///     through rga_witnesses / rga_witness_facts; the FFI view
///     never serializes lie text, so checks run against on-record
///     truth): a claim the record backs is SUPPORTED, a claim
///     the record clashes with (negation mismatch or disagreeing
///     numbers against a content-matching fact) is CONTRADICTED,
///     and the specific fact is cited either way.
///  b. SELF-CONTRADICTION CHECK against the SAME speaker's own
///     prior recorded claims (plus claims earlier in the same
///     statement, which are already on record by the time a
///     later claim is checked): shared content tokens above the
///     coverage threshold, plus a negation present on one side
///     only or numbers that disagree, flags CONTRADICTED with
///     the earlier claim cited. THIS IS A HEURISTIC — it sees
///     words and numbers, not meaning; a flagged pair is a
///     lexical clash to inspect, not proof of intent.
///  c. Anything neither check covers is UNVERIFIABLE. The
///     detector never guesses a verdict.
///
/// WHAT IT IS NOT: not a polygraph, not a truth oracle, not
/// semantic understanding. [labellingLine] states the mechanism
/// in one line and is shown on every surface. The verdict
/// vocabulary is SUPPORTED / CONTRADICTED / UNVERIFIABLE — the
/// detector never infers "LIE"; that word belongs only to the
/// daemon's scene data itself (a witness statement the config
/// marks with lie_text, surfaced by the interrogation path).
/// There is no lie probability and no percentage-of-lying
/// score: the credibility ledger is the running COUNTS of a
/// speaker's checked claims, and any ratio shown is the plain
/// arithmetic of those counts with the counts beside it.
///
/// EMPTY FACT BASE: the shipped daemon_config supplies no scene
/// facts, so check (a) is idle (the report says NO FACTS
/// AVAILABLE) until Richard supplies scene data. Check (b)
/// works from the first recorded statement onward — the record
/// is the detector's own, and it grows with real use.
///
/// Persistence: the statement record rides the app's existing
/// on-device path (SharedPreferences, the DannyLedger pattern).
/// The record retains the most recent [maxStatements] checked
/// statements; older ones roll off and stop contributing to
/// self-contradiction checks and to the ledger — the ledger
/// therefore covers the RETAINED record, and says so.
enum DetectorVerdict { supported, contradicted, unverifiable }

extension DetectorVerdictLabel on DetectorVerdict {
  String get label => switch (this) {
        DetectorVerdict.supported => 'SUPPORTED',
        DetectorVerdict.contradicted => 'CONTRADICTED',
        DetectorVerdict.unverifiable => 'UNVERIFIABLE',
      };
}

/// One statement as it entered the detector.
class RecordedStatement {
  const RecordedStatement({
    required this.speaker,
    required this.text,
    required this.at,
  });
  final String speaker;
  final String text;
  final DateTime at;

  Map<String, dynamic> toJson() => {
        'speaker': speaker,
        'text': text,
        'at': at.toIso8601String(),
      };

  factory RecordedStatement.fromJson(Map<String, dynamic> j) =>
      RecordedStatement(
        speaker: j['speaker'] as String,
        text: j['text'] as String,
        at: DateTime.parse(j['at'] as String),
      );
}

/// A self-contradiction citation: the speaker's own earlier
/// claim that a new claim clashes with, and the lexical signal.
class PriorCitation {
  const PriorCitation({
    required this.claim,
    required this.at,
    required this.signal,
  });

  /// The earlier claim sentence, verbatim from the record.
  final String claim;
  final DateTime at;

  /// 'negation mismatch' or 'numbers disagree: now {…} vs
  /// earlier {…}' — the deterministic signal that fired.
  final String signal;

  Map<String, dynamic> toJson() => {
        'claim': claim,
        'at': at.toIso8601String(),
        'signal': signal,
      };

  factory PriorCitation.fromJson(Map<String, dynamic> j) =>
      PriorCitation(
        claim: j['claim'] as String,
        at: DateTime.parse(j['at'] as String),
        signal: j['signal'] as String,
      );
}

/// The detector's verdict on ONE claim, composed only of the
/// checks that actually ran: the fact-check result (null when
/// the fact base is empty — the check was idle, not passed) and
/// the self-contradiction citation (null when no clash fired).
class ClaimVerdict {
  const ClaimVerdict({
    required this.claim,
    required this.verdict,
    this.factCheck,
    this.prior,
  });
  final String claim;
  final DetectorVerdict verdict;
  final ClaimCheck? factCheck;
  final PriorCitation? prior;

  String describe(String speaker) {
    final f = factCheck;
    final p = prior;
    return switch (verdict) {
      DetectorVerdict.supported =>
        'SUPPORTED: "$claim" — matches the record (${f!.fact!.witness}, '
            'fact ${f.fact!.id}: "${f.fact!.text}")'
            '${f.signal == null ? '' : ' — signal: ${f.signal}'}.',
      DetectorVerdict.contradicted => [
          'CONTRADICTED: "$claim"',
          if (f != null && f.fact != null)
            'vs the record (${f.fact!.witness}, fact ${f.fact!.id}: '
                '"${f.fact!.text}") — signal: ${f.signal}',
          if (p != null)
            'vs $speaker\'s own earlier statement '
                '(${p.at.toIso8601String().substring(0, 10)}): '
                '"${p.claim}" — signal: ${p.signal} '
                '(lexical self-contradiction heuristic)',
        ].join(' — '),
      DetectorVerdict.unverifiable =>
        'UNVERIFIABLE: "$claim" — no recorded fact covers it and it '
            'does not clash with $speaker\'s recorded statements.',
    };
  }

  Map<String, dynamic> toJson() => {
        'claim': claim,
        'verdict': verdict.name,
        'fact': factCheck == null
            ? null
            : {
                'verdict': factCheck!.verdict.name,
                'signal': factCheck!.signal,
                'witness': factCheck!.fact?.witness,
                'id': factCheck!.fact?.id,
                'text': factCheck!.fact?.text,
              },
        'prior': prior?.toJson(),
      };

  factory ClaimVerdict.fromJson(Map<String, dynamic> j) {
    ClaimCheck? fc;
    final rawFact = j['fact'];
    if (rawFact is Map<String, dynamic>) {
      final w = rawFact['witness'] as String?;
      fc = ClaimCheck(
        claim: j['claim'] as String,
        verdict: DiscernmentVerdict.values.byName(rawFact['verdict'] as String),
        fact: w == null
            ? null
            : WitnessFact(
                witness: w,
                id: rawFact['id'] as String? ?? '',
                text: rawFact['text'] as String? ?? '',
                // The citation needs the on-record truth only;
                // the scene's lie rule is not part of a citation.
                liePermitted: false,
              ),
        signal: rawFact['signal'] as String?,
      );
    }
    final rawPrior = j['prior'];
    return ClaimVerdict(
      claim: j['claim'] as String,
      verdict: DetectorVerdict.values.byName(j['verdict'] as String),
      factCheck: fc,
      prior: rawPrior is Map<String, dynamic>
          ? PriorCitation.fromJson(rawPrior)
          : null,
    );
  }
}

/// One checked statement kept in the persistent record: the
/// statement plus the verdicts it earned, so the credibility
/// ledger is a fold over the record and survives restarts
/// without re-checking (re-checking could change verdicts as
/// the record grows — history must not rewrite itself).
class CheckedStatement {
  const CheckedStatement({required this.statement, required this.claims});
  final RecordedStatement statement;
  final List<ClaimVerdict> claims;

  Map<String, dynamic> toJson() => {
        'statement': statement.toJson(),
        'claims': [for (final c in claims) c.toJson()],
      };

  factory CheckedStatement.fromJson(Map<String, dynamic> j) =>
      CheckedStatement(
        statement: RecordedStatement.fromJson(
            j['statement'] as Map<String, dynamic>),
        claims: [
          for (final raw in (j['claims'] as List<dynamic>? ?? const []))
            ClaimVerdict.fromJson(raw as Map<String, dynamic>),
        ],
      );
}

/// The readout for one freshly checked statement: per-claim
/// verdicts plus the composed counts line. Composed ONLY of the
/// claim verdicts — no aggregate score is derived beyond the
/// counts themselves.
class StatementReport {
  const StatementReport({
    required this.statement,
    required this.claims,
    required this.factBaseEmpty,
  });
  final RecordedStatement statement;
  final List<ClaimVerdict> claims;

  /// True when the daemon's fact table was empty for this check:
  /// fact checks were idle and the report must say so.
  final bool factBaseEmpty;

  int get supportedCount =>
      claims.where((c) => c.verdict == DetectorVerdict.supported).length;
  int get contradictedCount =>
      claims.where((c) => c.verdict == DetectorVerdict.contradicted).length;
  int get unverifiableCount =>
      claims.where((c) => c.verdict == DetectorVerdict.unverifiable).length;

  /// The composed readout line, e.g. "2 supported · 1
  /// contradicted · 3 unverifiable" — counts, nothing else.
  String headline() => '$supportedCount supported · $contradictedCount '
      'contradicted · $unverifiableCount unverifiable';

  /// The underlying discernment fact checks that ran (empty
  /// when the fact base was empty) — Danny's chain keeps
  /// reporting these alongside the detector readout.
  List<ClaimCheck> get factChecks =>
      [for (final c in claims) if (c.factCheck != null) c.factCheck!];

  List<String> lines() => [
        'LIE DETECTOR — ${statement.speaker}, '
            '${statement.at.toIso8601String().substring(0, 16)}: '
            '${headline()}',
        if (factBaseEmpty)
          'FACT BASE: NO FACTS AVAILABLE — the daemon holds no '
              'recorded witness facts (no scene data supplied), so '
              'fact checks were idle; verdicts rest on the '
              'self-contradiction check alone.',
        for (final c in claims) '- ${c.describe(statement.speaker)}',
        if (claims.isEmpty)
          '- No checkable claims in this statement (claims are '
              'sentences of 8+ characters, the intake rule).',
      ];

  String readout() => lines().join('\n');

  /// Prompt block for Danny's critique stage: the labelling
  /// line, the readout, and the speaker's credibility line.
  String promptBlock({Credibility? credibility}) => [
        'LIE DETECTOR (${LieDetector.labellingLine})',
        readout(),
        if (credibility != null)
          'SPEAKER RECORD: ${credibility.describe()}',
      ].join('\n');
}

/// A speaker's credibility ledger: the running REAL counts of
/// their checked claims over the retained record. A consistency
/// history — NOT a lie probability, NOT a trust score.
class Credibility {
  const Credibility({
    required this.speaker,
    required this.statements,
    required this.supported,
    required this.contradicted,
    required this.unverifiable,
  });
  final String speaker;
  final int statements;
  final int supported;
  final int contradicted;
  final int unverifiable;

  /// Claims the record could actually decide.
  int get decided => supported + contradicted;

  String describe() => '$speaker: $statements statement(s) checked — '
      '$supported supported · $contradicted contradicted · '
      '$unverifiable unverifiable claims on record'
      '${decided > 0 ? '; of the $decided claims the record could decide, $contradicted were contradicted' : ''}.';
}

class LieDetector {
  LieDetector({Discernment? discernment, List<CheckedStatement>? history})
      : _injectedFacts = discernment,
        _history = [...?history];

  /// The one-line mechanism statement shown on every surface.
  static const labellingLine = 'Detects contradictions against '
      'recorded facts and the speaker\'s own prior statements. It '
      'cannot detect lies that leave no contradiction, and it '
      'reads no body signals.';

  /// The record's retention cap. Older statements roll off and
  /// stop contributing to checks and ledgers (see class doc).
  static const maxStatements = 200;

  final Discernment? _injectedFacts;
  Discernment? _daemonFacts;
  final List<CheckedStatement> _history;

  /// The fact table fact checks run against. Injected in tests;
  /// in the app it resolves LAZILY from the daemon — MindStore
  /// boots before the daemon in main.dart, so a detector booted
  /// with the mind must not snapshot an empty table at boot.
  Discernment get discernment =>
      _injectedFacts ?? (_daemonFacts ??= Discernment.loadFromDaemon());

  /// Re-read the fact table from the daemon (no-op when facts
  /// were injected). Views call this when they open: the daemon
  /// is up by then, and scene data may have been (re)loaded.
  void refreshFacts() {
    if (_injectedFacts == null) {
      _daemonFacts = Discernment.loadFromDaemon();
    }
  }

  bool get hasFacts => discernment.hasFacts;
  List<CheckedStatement> get history => List.unmodifiable(_history);
  int get statementCount => _history.length;

  /// Speakers with anything on record, in record order.
  List<String> get speakers {
    final seen = <String>{};
    return [
      for (final s in _history)
        if (seen.add(s.statement.speaker)) s.statement.speaker,
    ];
  }

  /// Check one statement and (by default) keep it in the record.
  ///
  /// [facts] overrides the fact table for this check — Danny's
  /// chain passes its own discernment table so his Second Sight
  /// and the detector can never disagree about the record.
  StatementReport checkStatement({
    required String speaker,
    required String text,
    Discernment? facts,
    DateTime? at,
    bool record = true,
  }) {
    final table = facts ?? discernment;
    final when = at ?? DateTime.now();
    final claimTexts = Discernment.splitClaims(text);
    // The speaker's prior claims, in the order they were
    // recorded. Claims earlier in THIS statement join the list
    // as they are checked — sequential intake: by the time a
    // later claim is examined, the earlier ones are on record.
    final priors = <PriorCitation>[
      for (final s in _history)
        if (s.statement.speaker == speaker)
          for (final c in s.claims)
            PriorCitation(claim: c.claim, at: s.statement.at, signal: ''),
    ];
    final verdicts = <ClaimVerdict>[];
    for (final claim in claimTexts) {
      // (a) Fact check — idle when the fact base is empty.
      final factCheck = table.hasFacts ? table.check(claim) : null;
      // (b) Self-contradiction heuristic vs the prior claims.
      final prior = _selfContradiction(claim, priors);
      // (c) Compose: CONTRADICTED if either check fired;
      // SUPPORTED only when the record backs the claim and no
      // self-clash fired; otherwise UNVERIFIABLE.
      final factSays = factCheck?.verdict;
      final verdict = (factSays == DiscernmentVerdict.inconsistentWithFacts ||
              prior != null)
          ? DetectorVerdict.contradicted
          : factSays == DiscernmentVerdict.consistentWithFacts
              ? DetectorVerdict.supported
              : DetectorVerdict.unverifiable;
      verdicts.add(ClaimVerdict(
        claim: claim,
        verdict: verdict,
        factCheck: factCheck,
        prior: prior,
      ));
      priors.add(PriorCitation(claim: claim, at: when, signal: ''));
    }
    final stmt =
        RecordedStatement(speaker: speaker, text: text, at: when);
    final report = StatementReport(
      statement: stmt,
      claims: verdicts,
      factBaseEmpty: !table.hasFacts,
    );
    if (record) {
      _history.add(CheckedStatement(statement: stmt, claims: verdicts));
      if (_history.length > maxStatements) {
        _history.removeRange(0, _history.length - maxStatements);
      }
    }
    return report;
  }

  /// The self-contradiction heuristic. Deterministic: among the
  /// prior claims sharing enough content tokens with [claim],
  /// the one with the largest token overlap decides (ties keep
  /// the most recent); it fires only on the two signals a
  /// lexical check can actually see — a negation present on one
  /// side only, or numbers on both sides that do not intersect.
  /// Returns the citation, or null when nothing fires.
  PriorCitation? _selfContradiction(
      String claim, List<PriorCitation> priors) {
    final ct = Discernment.tokensOf(claim);
    final cn = Discernment.numbersOf(claim);
    // Coverage needs real shared content — the same rule as the
    // fact check: at least two content tokens (one when the
    // claim itself is that small).
    final needed = ct.length <= 1 ? 1 : 2;
    PriorCitation? best;
    var bestOverlap = 0;
    for (final p in priors) {
      final pt = Discernment.tokensOf(p.claim);
      final overlap = ct.intersection(pt).length;
      if (overlap < needed) continue;
      String? signal;
      if (Discernment.isNegated(ct) != Discernment.isNegated(pt)) {
        signal = 'negation mismatch';
      } else {
        final pn = Discernment.numbersOf(p.claim);
        if (cn.isNotEmpty && pn.isNotEmpty && cn.intersection(pn).isEmpty) {
          signal = 'numbers disagree: now $cn vs earlier $pn';
        }
      }
      if (signal == null) continue;
      if (overlap > bestOverlap ||
          (overlap == bestOverlap &&
              best != null &&
              !p.at.isBefore(best.at))) {
        bestOverlap = overlap;
        best = PriorCitation(claim: p.claim, at: p.at, signal: signal);
      }
    }
    return best;
  }

  /// The credibility ledger for one speaker: a fold over the
  /// retained record. A speaker with nothing recorded gets
  /// zero counts, stated as such — never an assumed record.
  Credibility credibilityFor(String speaker) {
    var statements = 0, sup = 0, con = 0, unv = 0;
    for (final s in _history) {
      if (s.statement.speaker != speaker) continue;
      statements++;
      for (final c in s.claims) {
        switch (c.verdict) {
          case DetectorVerdict.supported:
            sup++;
          case DetectorVerdict.contradicted:
            con++;
          case DetectorVerdict.unverifiable:
            unv++;
        }
      }
    }
    return Credibility(
      speaker: speaker,
      statements: statements,
      supported: sup,
      contradicted: con,
      unverifiable: unv,
    );
  }

  List<Credibility> get allCredibility =>
      [for (final s in speakers) credibilityFor(s)];

  // ---- persistence (SharedPreferences, the mind-store path) ----

  static const _key = 'lie_detector_v1';
  static LieDetector? instance;

  Map<String, dynamic> toJson() => {
        'version': 1,
        'statements': [for (final s in _history) s.toJson()],
      };

  factory LieDetector.fromJson(Map<String, dynamic> j,
      {Discernment? discernment}) {
    final history = <CheckedStatement>[];
    final list = j['statements'];
    if (list is List) {
      for (final raw in list) {
        if (raw is Map<String, dynamic>) {
          try {
            history.add(CheckedStatement.fromJson(raw));
          } catch (_) {
            // A corrupt entry is dropped, never repaired into a
            // verdict it didn't earn.
          }
        }
      }
    }
    return LieDetector(discernment: discernment, history: history);
  }

  /// Load the statement record. Facts are NOT loaded here —
  /// they resolve lazily from the daemon (see [discernment]),
  /// because the mind boots before the daemon in main.dart.
  static Future<LieDetector> boot({Discernment? discernment}) async {
    var detector = LieDetector(discernment: discernment);
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null) {
        detector = LieDetector.fromJson(
            jsonDecode(raw) as Map<String, dynamic>,
            discernment: discernment);
      }
    } catch (_) {
      // Unreadable store = a fresh record; it claims no history.
      detector = LieDetector(discernment: discernment);
    }
    instance = detector;
    return detector;
  }

  /// The shared detector for the app session, booting on first
  /// use — so no surface ever finds it silently absent (the
  /// boot-consistency rule from Danny's stores).
  static Future<LieDetector> acquire() async =>
      instance ?? await boot();

  Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(toJson()));
    } catch (_) {
      // Best-effort like the mind store: a failed save is
      // retried on the next checked statement; nothing claims
      // it succeeded.
    }
  }
}
