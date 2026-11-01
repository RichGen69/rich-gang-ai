import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rich_gang_ai/core/danny_discernment.dart';
import 'package:rich_gang_ai/core/lie_detector.dart';

/// Lie Detector locks (2026-10-23): the detector is a
/// contradiction instrument, not a truth oracle — fact checks
/// cite the clashing/backing fact, self-contradictions cite the
/// speaker's own earlier claim, everything else is UNVERIFIABLE,
/// an empty fact base reports NO FACTS AVAILABLE while the
/// self-check keeps working, and the credibility ledger is the
/// plain counts of checked claims (no lie score).
///
/// Fixtures are written in the daemon config's "facts" shape
/// (docs/SCENE_FORMAT.md) and parsed the way the FFI facts view
/// presents them — the parser below deliberately never reads
/// "lie_text", exactly like rga_witness_facts, which never
/// serializes it.
List<WitnessFact> factsFromConfigJson(String configJson) {
  final doc = jsonDecode(configJson) as Map<String, dynamic>;
  final witnesses =
      (doc['facts'] as Map<String, dynamic>)['witnesses']
          as Map<String, dynamic>;
  return [
    for (final entry in witnesses.entries)
      for (final raw
          in (entry.value as List<dynamic>).cast<Map<String, dynamic>>())
        WitnessFact(
          witness: entry.key,
          id: raw['id'] as String,
          text: raw['text'] as String,
          liePermitted: raw['lie_permitted'] as bool? ?? false,
        ),
  ];
}

const _configJson = '''
{"facts": {"witnesses": {"ada": [
  {"id": "vault",
   "text": "The vault door was opened at 10 by the night guard",
   "lie_permitted": false},
  {"id": "bell",
   "text": "The brass bell rang at dawn in the hall",
   "lie_permitted": false}
]}}}
''';

LieDetector detectorWithFacts() => LieDetector(
    discernment: Discernment(factsFromConfigJson(_configJson)));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    LieDetector.instance = null;
  });

  group('fact checks against the recorded fact table', () {
    test('a claim the record backs is SUPPORTED, fact cited', () {
      final r = detectorWithFacts().checkStatement(
          speaker: 'ada', text: 'The vault door was opened at 10.');
      expect(r.supportedCount, 1);
      expect(r.contradictedCount, 0);
      expect(r.claims.single.factCheck?.fact?.id, 'vault');
      expect(r.claims.single.describe('ada'), contains('SUPPORTED'));
      expect(r.headline(), '1 supported · 0 contradicted · 0 unverifiable');
    });

    test('a claim the record clashes with is CONTRADICTED, fact cited',
        () {
      final r = detectorWithFacts().checkStatement(
          speaker: 'ada', text: 'The vault door was opened at 9.');
      expect(r.contradictedCount, 1);
      final c = r.claims.single;
      expect(c.verdict, DetectorVerdict.contradicted);
      expect(c.factCheck?.fact?.id, 'vault');
      expect(c.factCheck?.signal, contains('numbers disagree'));
      expect(c.describe('ada'), contains('CONTRADICTED'));
      expect(c.describe('ada'), contains('vault'));
    });

    test('a claim no fact covers is UNVERIFIABLE — never guessed', () {
      final r = detectorWithFacts().checkStatement(
          speaker: 'ada',
          text: 'The soup at the marina tasted of lemon and smoke.');
      expect(r.unverifiableCount, 1);
      expect(r.claims.single.verdict, DetectorVerdict.unverifiable);
      expect(r.claims.single.factCheck?.verdict,
          DiscernmentVerdict.noFactCoverage);
      expect(r.claims.single.describe('ada'), contains('UNVERIFIABLE'));
    });
  });

  group('self-contradiction against the speaker\'s own record', () {
    test('a negation clash with an earlier claim is CONTRADICTED '
        'with the earlier claim cited', () {
      final d = detectorWithFacts();
      final first = d.checkStatement(
          speaker: 'bob', text: 'I drove the red truck to the harbor.');
      expect(first.unverifiableCount, 1);
      final second = d.checkStatement(
          speaker: 'bob',
          text: 'I never drove the red truck to the harbor.');
      expect(second.contradictedCount, 1);
      final c = second.claims.single;
      expect(c.prior, isNotNull);
      expect(c.prior?.claim, 'I drove the red truck to the harbor.');
      expect(c.prior?.signal, 'negation mismatch');
      expect(c.describe('bob'), contains('own earlier statement'));
      expect(c.describe('bob'), contains('heuristic'));
    });

    test('numbers that change between statements are CONTRADICTED',
        () {
      final d = detectorWithFacts();
      d.checkStatement(
          speaker: 'cy',
          text: 'The meeting in the hall had 12 people present.');
      final second = d.checkStatement(
          speaker: 'cy',
          text: 'The meeting in the hall had 9 people present.');
      expect(second.contradictedCount, 1);
      expect(second.claims.single.prior?.signal,
          contains('numbers disagree'));
    });

    test('another speaker\'s statements never incriminate', () {
      final d = detectorWithFacts();
      d.checkStatement(
          speaker: 'bob', text: 'I drove the red truck to the harbor.');
      final other = d.checkStatement(
          speaker: 'ada',
          text: 'I never drove the red truck to the harbor.');
      expect(other.claims.single.prior, isNull);
      expect(other.unverifiableCount, 1);
    });

    test('claims earlier in the SAME statement are already on '
        'record for later claims', () {
      final r = detectorWithFacts().checkStatement(
          speaker: 'bob',
          text: 'I drove the red truck to the harbor. '
              'I never drove the red truck to the harbor.');
      expect(r.claims, hasLength(2));
      expect(r.claims[0].verdict, DetectorVerdict.unverifiable);
      expect(r.claims[1].verdict, DetectorVerdict.contradicted);
      expect(r.claims[1].prior?.claim,
          'I drove the red truck to the harbor.');
    });
  });

  group('empty fact base', () {
    test('reports NO FACTS AVAILABLE, fact checks idle, and the '
        'self-check still works', () {
      final d = LieDetector(discernment: Discernment(const []));
      expect(d.hasFacts, isFalse);
      final first = d.checkStatement(
          speaker: 'bob', text: 'I drove the red truck to the harbor.');
      expect(first.factBaseEmpty, isTrue);
      expect(first.claims.single.factCheck, isNull);
      expect(first.unverifiableCount, 1);
      expect(first.readout(), contains('NO FACTS AVAILABLE'));
      final second = d.checkStatement(
          speaker: 'bob',
          text: 'I never drove the red truck to the harbor.');
      expect(second.contradictedCount, 1);
      expect(second.claims.single.prior, isNotNull);
    });

    test('the labelling line states the mechanism and its limits',
        () {
      expect(LieDetector.labellingLine,
          contains('cannot detect lies that leave no contradiction'));
      expect(LieDetector.labellingLine,
          contains('reads no body signals'));
    });
  });

  group('credibility ledger — counts, never a lie score', () {
    test('counts accumulate per speaker across checks', () {
      final d = detectorWithFacts();
      d.checkStatement(
          speaker: 'ada', text: 'The vault door was opened at 10.');
      d.checkStatement(
          speaker: 'ada', text: 'The vault door was opened at 9.');
      d.checkStatement(
          speaker: 'ada',
          text: 'The soup at the marina tasted of lemon and smoke.');
      d.checkStatement(
          speaker: 'bob', text: 'I drove the red truck to the harbor.');
      final ada = d.credibilityFor('ada');
      expect(ada.statements, 3);
      expect(ada.supported, 1);
      expect(ada.contradicted, 1);
      expect(ada.unverifiable, 1);
      expect(ada.describe(), contains('1 supported · 1 contradicted'));
      final bob = d.credibilityFor('bob');
      expect(bob.statements, 1);
      expect(bob.unverifiable, 1);
      final nobody = d.credibilityFor('nobody');
      expect(nobody.statements, 0);
      expect(nobody.supported + nobody.contradicted + nobody.unverifiable,
          0);
    });

    test('the record persists: after a restart the ledger and '
        'the self-check history are intact', () async {
      SharedPreferences.setMockInitialValues({});
      final d = detectorWithFacts();
      d.checkStatement(
          speaker: 'bob', text: 'I drove the red truck to the harbor.');
      d.checkStatement(
          speaker: 'ada', text: 'The vault door was opened at 10.');
      await d.save();

      final booted = await LieDetector.boot(
          discernment: Discernment(factsFromConfigJson(_configJson)));
      expect(booted.statementCount, 2);
      expect(booted.credibilityFor('ada').supported, 1);
      expect(booted.credibilityFor('bob').unverifiable, 1);
      // The restored history still incriminates a fresh clash.
      final clash = booted.checkStatement(
          speaker: 'bob',
          text: 'I never drove the red truck to the harbor.');
      expect(clash.contradictedCount, 1);
      expect(clash.claims.single.prior?.claim,
          'I drove the red truck to the harbor.');
      // And the stored verdicts were kept, not re-derived.
      final stored = booted.history
          .firstWhere((s) => s.statement.speaker == 'ada');
      expect(stored.claims.single.verdict, DetectorVerdict.supported);
      expect(stored.claims.single.factCheck?.fact?.id, 'vault');
    });

    test('record=false checks without keeping the statement', () {
      final d = detectorWithFacts();
      d.checkStatement(
          speaker: 'ada',
          text: 'The vault door was opened at 10.',
          record: false);
      expect(d.statementCount, 0);
      expect(d.credibilityFor('ada').statements, 0);
    });
  });
}
