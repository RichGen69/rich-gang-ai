import 'dart:convert';
import 'native_bridge.dart';

/// Danny's DISCERNMENT pass — his "second sight" gift.
///
/// WHAT THIS IS: a deterministic, lexical consistency check of
/// claims against the facts recorded in the Rust daemon's witness
/// fact table (the interrogation scene data Richard supplies in
/// daemon_config.json — rga_witnesses / rga_witness_facts). Each
/// checked claim gets exactly one verdict:
///
///  - CONSISTENT-WITH-FACTS: the claim shares its content tokens
///    (and any numbers) with a recorded fact and carries no
///    negation mismatch against it;
///  - INCONSISTENT-WITH-FACTS: the claim shares content tokens
///    with a recorded fact but contradicts it on the signals a
///    lexical check can actually see — a negation present on one
///    side only, or numbers that disagree;
///  - NO-FACT-COVERAGE: no recorded fact speaks to the claim at
///    all, so the record neither backs nor contradicts it.
///
/// WHAT THIS IS NOT: a lie detector, a truth oracle, or semantic
/// understanding. It compares words and numbers against a recorded
/// table, the same honest labelling as the app's lexical recall
/// and lexical appraisal. When the daemon holds no facts (the
/// shipped config supplies none — scene data is Richard's to
/// provide), the pass reports NO FACTS AVAILABLE and checks
/// nothing, rather than pretending to verify against an empty
/// record. A claim nobody recorded a fact about is UNVERIFIED
/// against the record — never "true" and never "a lie".
class WitnessFact {
  const WitnessFact({
    required this.witness,
    required this.id,
    required this.text,
    required this.liePermitted,
  });
  final String witness;
  final String id;
  final String text;

  /// The scene's game rule: this witness may lie about this fact
  /// in interrogation play. The fact TEXT here is always the
  /// on-record truth (the FFI view never serializes lie text).
  final bool liePermitted;
}

enum DiscernmentVerdict {
  consistentWithFacts,
  inconsistentWithFacts,
  noFactCoverage,
}

class ClaimCheck {
  const ClaimCheck({
    required this.claim,
    required this.verdict,
    this.fact,
    this.signal,
  });
  final String claim;
  final DiscernmentVerdict verdict;

  /// The recorded fact the verdict rests on (null for no coverage).
  final WitnessFact? fact;

  /// The deterministic signal that decided it ('negation
  /// mismatch', 'numbers disagree: claim {9} vs record {10}',
  /// 'content overlap') — shown so the check is inspectable.
  final String? signal;

  String get verdictLabel => switch (verdict) {
        DiscernmentVerdict.consistentWithFacts => 'CONSISTENT-WITH-FACTS',
        DiscernmentVerdict.inconsistentWithFacts =>
          'INCONSISTENT-WITH-FACTS',
        DiscernmentVerdict.noFactCoverage => 'NO-FACT-COVERAGE',
      };

  String describe() => fact == null
      ? '$verdictLabel: "$claim" — no recorded fact covers this.'
      : '$verdictLabel: "$claim" vs the record (${fact!.witness}, '
          'fact ${fact!.id}: "${fact!.text}")'
          '${signal == null ? '' : ' — signal: $signal'}.';
}

class Discernment {
  Discernment(this.facts);
  final List<WitnessFact> facts;

  bool get hasFacts => facts.isNotEmpty;

  static const _stopwords = {
    'the', 'a', 'an', 'and', 'or', 'of', 'to', 'in', 'on', 'at',
    'was', 'were', 'is', 'are', 'be', 'been', 'it', 'its', 'that',
    'this', 'with', 'for', 'from', 'by', 'as', 'had', 'has', 'have',
    'he', 'she', 'they', 'we', 'you', 'i', 'his', 'her', 'their',
    'who', 'what', 'when', 'where', 'which', 'there', 'then', 'so',
    'but', 'if', 'than', 'too', 'very', 'just',
  };

  static const _negations = {
    'not', 'never', 'no', "isn't", "wasn't", "aren't", "weren't",
    "don't", "didn't", "doesn't", "can't", "couldn't", "won't",
    "wouldn't", 'none', 'nobody', 'nothing', 'nowhere', 'neither',
    'nor', 'without',
  };

  static Set<String> _tokens(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r"[^a-z0-9'\s]"), ' ')
      .split(RegExp(r'\s+'))
      .where((w) => w.length > 2 && !_stopwords.contains(w))
      .toSet();

  static Set<String> _numbers(String s) =>
      RegExp(r'\d+(?:\.\d+)?').allMatches(s).map((m) => m.group(0)!).toSet();

  static bool _negated(Set<String> tokens) =>
      tokens.any(_negations.contains);

  // The lexical machinery, exposed so the app-level Lie Detector
  // (lie_detector.dart) runs on this ONE tokenizer / negation set /
  // number extractor instead of a second copy that could drift.
  // Same limits as the pass itself: words and numbers, no semantics.
  static Set<String> tokensOf(String s) => _tokens(s);
  static Set<String> numbersOf(String s) => _numbers(s);
  static bool isNegated(Set<String> tokens) => _negated(tokens);

  /// Split a text into claim-sized sentences — the same split
  /// [checkText] uses, exposed for the Lie Detector's intake so a
  /// "claim" means exactly the same thing in both engines.
  static List<String> splitClaims(String text) => [
        for (final s in text
            .split(RegExp(r'(?<=[.!?])\s+'))
            .map((s) => s.trim())
            .where((s) => s.length >= 8))
          s,
      ];

  /// Check one claim against the recorded facts. Deterministic:
  /// the fact with the largest content-token overlap decides; ties
  /// keep the earliest fact in table order.
  ClaimCheck check(String claim) {
    final ct = _tokens(claim);
    final cn = _numbers(claim);
    WitnessFact? best;
    var bestOverlap = 0;
    for (final f in facts) {
      final overlap = ct.intersection(_tokens(f.text)).length;
      if (overlap > bestOverlap) {
        bestOverlap = overlap;
        best = f;
      }
    }
    // Coverage needs real shared content: at least two content
    // tokens (or one token when the claim itself is that small) —
    // a single shared common word is not the record speaking.
    final needed = ct.length <= 1 ? 1 : 2;
    if (best == null || bestOverlap < needed) {
      return ClaimCheck(
          claim: claim, verdict: DiscernmentVerdict.noFactCoverage);
    }
    final ft = _tokens(best.text);
    if (_negated(ct) != _negated(ft)) {
      return ClaimCheck(
        claim: claim,
        verdict: DiscernmentVerdict.inconsistentWithFacts,
        fact: best,
        signal: 'negation mismatch',
      );
    }
    final fn = _numbers(best.text);
    if (cn.isNotEmpty && fn.isNotEmpty && cn.intersection(fn).isEmpty) {
      return ClaimCheck(
        claim: claim,
        verdict: DiscernmentVerdict.inconsistentWithFacts,
        fact: best,
        signal: 'numbers disagree: claim $cn vs record $fn',
      );
    }
    return ClaimCheck(
      claim: claim,
      verdict: DiscernmentVerdict.consistentWithFacts,
      fact: best,
      signal: 'content overlap ($bestOverlap tokens)',
    );
  }

  /// Split a text into claim-sized sentences and check each one.
  /// With no facts loaded, returns an empty list — the caller
  /// reports NO FACTS AVAILABLE from [hasFacts] instead of dressing
  /// an empty record up as a completed check.
  List<ClaimCheck> checkText(String text) {
    if (!hasFacts) return const [];
    return [for (final s in splitClaims(text)) check(s)];
  }

  /// Prompt block for the critique stage: only the checks that
  /// found something to say — inconsistencies first, then what
  /// the record backs. No-coverage claims are counted, not listed:
  /// the record's silence about them is the whole point.
  String promptBlock(List<ClaimCheck> checks) {
    if (!hasFacts) {
      return 'DISCERNMENT: no witness facts are recorded in the '
          'daemon (no scene data supplied), so no claim could be '
          'cross-checked against the record. Nothing here is '
          'verified against facts — do not claim otherwise. (This '
          'pass is a consistency check against recorded facts, NOT '
          'a lie detector.)';
    }
    final bad = checks
        .where((c) => c.verdict == DiscernmentVerdict.inconsistentWithFacts)
        .toList();
    final good = checks
        .where((c) => c.verdict == DiscernmentVerdict.consistentWithFacts)
        .toList();
    final none = checks.length - bad.length - good.length;
    return [
      'DISCERNMENT (lexical consistency check against the recorded '
          'witness facts — NOT a lie detector):',
      for (final c in bad) '- ${c.describe()}',
      for (final c in good) '- ${c.describe()}',
      if (none > 0)
        '- $none claim(s) had NO-FACT-COVERAGE: the record neither '
            'backs nor contradicts them; treat them as unverified.',
    ].join('\n');
  }

  /// Load every recorded witness fact through the daemon bridge.
  /// Any failure (daemon offline, error docs, no scene) returns an
  /// empty set — [hasFacts] false — and the pass reports itself
  /// unavailable instead of checking against nothing.
  static Discernment loadFromDaemon([NativeBridge? bridge]) {
    try {
      final b = bridge ?? NativeBridge();
      final wdoc = jsonDecode(b.witnesses()) as Map<String, dynamic>;
      final names = (wdoc['witnesses'] as List<dynamic>? ?? const [])
          .cast<String>();
      final facts = <WitnessFact>[];
      for (final name in names) {
        final fdoc =
            jsonDecode(b.witnessFacts(name)) as Map<String, dynamic>;
        final list = fdoc['facts'];
        if (list is! List) continue;
        for (final raw in list) {
          if (raw is! Map<String, dynamic>) continue;
          facts.add(WitnessFact(
            witness: name,
            id: raw['id'] as String? ?? '',
            text: raw['text'] as String? ?? '',
            liePermitted: raw['lie_permitted'] as bool? ?? false,
          ));
        }
      }
      return Discernment(facts);
    } catch (_) {
      return Discernment(const []);
    }
  }
}
