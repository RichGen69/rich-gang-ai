import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rich_gang_ai/core/character.dart';
import 'package:rich_gang_ai/core/danny_discernment.dart';
import 'package:rich_gang_ai/core/inference_router.dart';
import 'package:rich_gang_ai/core/lie_detector.dart';
import 'package:rich_gang_ai/core/persistent_mind.dart';
import 'package:rich_gang_ai/core/roundtable.dart';

/// Danny at the Roundtable (2026-10-25): his flagship chain —
/// perceive → appraise → discern → draft → critique → revise →
/// respond → reflect, critique/revise never skipped — must run
/// for his table turns exactly as it does in one-to-one chat,
/// and the stimulus must be attributed to its real speaker in
/// the Lie Detector record (the previous speaker, or Richard
/// when the topic itself is the stimulus) — never defaulted to
/// Richard when another agent spoke last.
///
/// The speaker pick is deliberately non-deterministic (jitter in
/// TurnEngine), so the test drives the table until a Danny turn
/// appears rather than assuming he speaks first. The session is
/// paused, never stopped, at the end: stop() touches voice
/// platform channels, which have no test implementation.
class _ScriptedTableRouter extends InferenceRouter {
  final List<String> prompts = [];

  @override
  Future<String> run(InferenceTask task, String prompt,
      {String? grammar}) async {
    prompts.add(prompt);
    if (prompt.contains('inner reasoning of Danny')) {
      return '{"situation":"Dan just spoke at the table",'
          '"feeling":"focused","memory":"The record shows nothing '
          'about this topic","goal":"answer with receipts",'
          '"options":["trust it","check it"],"chosen":"check it",'
          '"why":"receipts first"}';
    }
    if (prompt.contains('critical inner voice')) {
      return 'The draft hedges and repeats nothing checked.';
    }
    if (prompt.contains('Your first draft was:')) {
      return 'TABLE REVISED: receipts checked, verdict stands.';
    }
    if (prompt.contains('Give your best first answer')) {
      return 'TABLE DRAFT: a first pass, unchecked.';
    }
    return 'Dan at the table: noted, Boss.';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    MindStore.instance = null;
    LieDetector.instance = null;
  });

  test('Danny table turns run his flagship chain, not the generic path',
      () async {
    final registry = CharacterRegistry.parse(
        File('assets/characters.json').readAsStringSync());
    final mind = MindStore(registry);
    MindStore.instance = mind;
    // Empty fact table: discernment reports NO FACTS AVAILABLE
    // instead of checking against nothing.
    final detector = LieDetector(discernment: Discernment(const []));
    LieDetector.instance = detector;

    final router = _ScriptedTableRouter();
    final session = RoundtableSession(
      affects: mind.affects,
      router: router,
    );
    final danny =
        registry.all.firstWhere((c) => c.id == 'danny');
    final dan = registry.all.firstWhere((c) => c.id == 'dan');
    session.start(
      withCast: [danny, dan],
      topic: 'receipts and verification',
    );

    // Drive the table until Danny speaks (speaker pick has
    // jitter, so the first turn may be Dan's generic turn).
    RoundtableTurn? dannyTurn;
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (dannyTurn == null && DateTime.now().isBefore(deadline)) {
      for (final t in session.transcript) {
        if (t.speakerId == 'danny') dannyTurn = t;
      }
      if (dannyTurn == null) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
    }
    session.pause();
    expect(dannyTurn, isNotNull,
        reason: 'no Danny turn appeared within 30s');

    // The revision ships, never the draft.
    expect(dannyTurn!.text,
        'TABLE REVISED: receipts checked, verdict stands.');
    expect(dannyTurn.text, isNot(contains('unchecked')));
    // The chain's appraise stage fed this turn's thought.
    expect(dannyTurn.thoughtSummary, isNotNull);

    // The full chain ran for him: a draft prompt AND a critique
    // prompt reached the router. The generic path sends neither.
    expect(
        router.prompts.any((p) => p.contains('Give your best first answer')),
        isTrue,
        reason: 'no draft stage prompt — Danny took the generic path');
    expect(router.prompts.any((p) => p.contains('critical inner voice')),
        isTrue,
        reason: 'no critique stage prompt — his DOUBLE-CHECK did not run');

    // Attribution: the stimulus for Danny's turn is the line
    // before it (or the topic, if he spoke first), and the
    // detector recorded exactly that speaker — not a default.
    final idx = session.transcript.indexOf(dannyTurn);
    final stimulusSpeaker = idx > 0
        ? session.transcript[idx - 1].speakerId
        : 'richard';
    expect(
        detector.history.any((s) => s.statement.speaker == stimulusSpeaker),
        isTrue,
        reason: 'detector record does not carry the stimulus speaker '
            '($stimulusSpeaker)');
    if (stimulusSpeaker != 'richard') {
      // The previous agent's line must not have been recorded
      // as Richard's statement.
      final richardStatements = detector.history
          .where((s) => s.statement.speaker == 'richard')
          .toList();
      expect(richardStatements, isEmpty);
    }
  });
}
