import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rich_gang_ai/core/affect_engine.dart';
import 'package:rich_gang_ai/core/character.dart';
import 'package:rich_gang_ai/core/character_agent.dart';
import 'package:rich_gang_ai/core/danny_chain.dart';
import 'package:rich_gang_ai/core/danny_discernment.dart';
import 'package:rich_gang_ai/core/danny_ledger.dart';
import 'package:rich_gang_ai/core/danny_upgrades.dart';
import 'package:rich_gang_ai/core/inference_router.dart';
import 'package:rich_gang_ai/core/persistent_mind.dart';
import 'package:rich_gang_ai/core/self_model.dart';
import 'package:rich_gang_ai/core/thinking.dart';
import 'package:rich_gang_ai/core/voice_engine.dart';

/// Danny's flagship-model locks (2026-10-23): discernment is a
/// lexical consistency check (not a lie detector), the self-
/// upgrade loop is allowlist-only / bounded / logged / reversible
/// with an append-only accountability record, the ledger records
/// only real appraisal events, and his chain runs every stage —
/// critique and revise included — on every reply.
CharacterDef dannyDef() {
  final raw = File('assets/characters.json').readAsStringSync();
  final doc = jsonDecode(raw) as Map<String, dynamic>;
  final j = (doc['characters'] as List<dynamic>)
      .cast<Map<String, dynamic>>()
      .firstWhere((c) => c['id'] == 'danny');
  return CharacterDef.fromJson(j);
}

const _facts = [
  WitnessFact(
    witness: 'guard',
    id: 'f1',
    text: 'The vault door was opened at 10 by the night guard',
    liePermitted: false,
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('discernment (second sight)', () {
    final d = Discernment(_facts);

    test('a claim matching the record is CONSISTENT-WITH-FACTS', () {
      final c = d.check('The vault door was opened at 10.');
      expect(c.verdict, DiscernmentVerdict.consistentWithFacts);
      expect(c.fact?.id, 'f1');
    });

    test('a number that disagrees is INCONSISTENT-WITH-FACTS', () {
      final c = d.check('The vault door was opened at 9.');
      expect(c.verdict, DiscernmentVerdict.inconsistentWithFacts);
      expect(c.signal, contains('numbers disagree'));
    });

    test('a negation the record does not carry is INCONSISTENT', () {
      final c = d.check('The vault door was not opened at 10.');
      expect(c.verdict, DiscernmentVerdict.inconsistentWithFacts);
      expect(c.signal, contains('negation'));
    });

    test('a claim the record does not speak to has NO COVERAGE', () {
      final c = d.check('The chef poached the salmon beautifully.');
      expect(c.verdict, DiscernmentVerdict.noFactCoverage);
      expect(c.fact, isNull);
    });

    test('no facts = the pass reports itself unavailable', () {
      final empty = Discernment(const []);
      expect(empty.hasFacts, isFalse);
      expect(empty.checkText('The vault door was opened at 9.'), isEmpty);
      expect(empty.promptBlock(const []),
          contains('no witness facts are recorded'));
      expect(empty.promptBlock(const []), contains('NOT a lie detector'));
    });
  });

  group('the ledger', () {
    test('records gratitude and slights from real appraisal events only',
        () {
      final l = DannyLedger();
      expect(
          l.record(
              appraisalEvent: 'praised', whoId: 'sally', excerpt: 'great call'),
          isTrue);
      expect(
          l.record(
              appraisalEvent: 'insulted',
              whoId: 'freddy',
              excerpt: 'useless machine'),
          isTrue);
      // Not a ledger category: affinity-neutral events are refused.
      expect(
          l.record(appraisalEvent: 'novelty', whoId: 'leo', excerpt: 'new'),
          isFalse);
      expect(l.gratitudeCount, 1);
      expect(l.slightCount, 1);
      expect(l.summaryLine(), contains('1 kindness'));
      expect(l.entries.first.reason, 'praised');
      expect(l.entries.first.at, isNotNull);
    });

    test('persists and restores through the shared prefs path', () async {
      SharedPreferences.setMockInitialValues({});
      final l = await DannyLedger.boot();
      l.record(appraisalEvent: 'thanked', whoId: 'richard', excerpt: 'thanks');
      await l.save();
      final restored = await DannyLedger.boot();
      expect(restored.length, 1);
      expect(restored.entries.single.whoId, 'richard');
    });
  });

  group('self-upgrade guardrails', () {
    test('Danny-only: constructing for another character throws', () {
      final raw = File('assets/characters.json').readAsStringSync();
      final doc = jsonDecode(raw) as Map<String, dynamic>;
      final dan = CharacterDef.fromJson((doc['characters'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .firstWhere((c) => c['id'] == 'dan'));
      expect(() => DannyUpgradeController(dan), throwsArgumentError);
    });

    test('allowlisted change applies, snapshots, and hits the shelf', () {
      final c = DannyUpgradeController(dannyDef());
      c.applyChange('baseline_dominance', 0.75, reason: 'test tuning');
      expect(c.state.dominance, 0.75);
      expect(c.state.version, 1);
      expect(c.trophyShelf, hasLength(1));
      expect(c.trophyShelf.single.reason, 'test tuning');
      expect(c.trophyShelf.single.snapshotVersion, 1);
    });

    test('out-of-band values are rejected, logged, and change nothing',
        () {
      final c = DannyUpgradeController(dannyDef());
      expect(() => c.applyChange('baseline_dominance', 0.99, reason: 'greed'),
          throwsA(isA<DannyUpgradeException>()));
      expect(c.state.dominance, 0.7);
      expect(c.state.version, 0);
      expect(c.trophyShelf, isEmpty);
      expect(c.log.single.kind, AccountabilityKind.rejection);
    });

    test('protected sections can never be written — identity is stable',
        () {
      final def = dannyDef();
      final coreBefore = def.moralCore;
      final guardsBefore = def.guardrails;
      final c = DannyUpgradeController(def);
      for (final param in [
        'moral_core',
        'guardrails',
        'core',
        'personality',
        'speech_style',
        'voice',
        'portrait',
        'status',
        'zodiac',
        'age_gated',
        'self_knowledge',
      ]) {
        expect(() => c.applyChange(param, 'tampered', reason: 'attack'),
            throwsA(isA<DannyUpgradeException>()),
            reason: param);
      }
      // Every attempt is on his record; the definition never moved.
      expect(
          c.log.where((e) => e.kind == AccountabilityKind.rejection).length,
          11);
      expect(c.trophyShelf, isEmpty);
      expect(def.moralCore, coreBefore);
      expect(def.guardrails, guardsBefore);
      expect(def.moralCore, contains('MORAL CORE'));
    });

    test('self_note is writable but length-bounded', () {
      final c = DannyUpgradeController(dannyDef());
      c.applyChange('self_note', 'I verify first. Twice.',
          reason: 'reflection');
      expect(c.state.selfNote, contains('verify'));
      expect(() => c.applyChange('self_note', 'x' * 281, reason: 'essay'),
          throwsA(isA<DannyUpgradeException>()));
      expect(c.state.selfNote, contains('verify'));
    });

    test('kill switch blocks everything and is itself logged', () {
      final c = DannyUpgradeController(dannyDef());
      c.setEnabled(false, reason: 'Richard flipped it');
      expect(() => c.applyChange('volatility', 0.25, reason: 'try'),
          throwsA(isA<DannyUpgradeException>()));
      expect(
          c.log.map((e) => e.kind),
          containsAll(
              [AccountabilityKind.killSwitch, AccountabilityKind.rejection]));
      c.setEnabled(true, reason: 'back on');
      c.applyChange('volatility', 0.25, reason: 'works again');
      expect(c.state.volatility, 0.25);
    });

    test('rollback restores an earlier snapshot and only APPENDS', () {
      final c = DannyUpgradeController(dannyDef());
      c.applyChange('talkativeness', 0.85, reason: 'one');
      c.applyChange('talkativeness', 0.88, reason: 'two');
      final logBefore = c.log.length;
      final firstEntry = c.log.first;
      c.rollback(0, reason: 'Richard reviewed the shelf');
      expect(c.state.talkativeness, 0.8);
      expect(c.log.length, greaterThan(logBefore));
      expect(c.log.first, same(firstEntry)); // history never rewritten
      expect(c.log.last.kind, AccountabilityKind.rollback);
      expect(() => c.rollback(99, reason: 'no such version'),
          throwsA(isA<DannyUpgradeException>()));
    });

    test('dream tuning nudges inside the bands, and no-ops honestly',
        () {
      final c = DannyUpgradeController(dannyDef());
      // Affect sitting exactly on the baselines: nothing to tune.
      expect(
          c.tuneFromReflection(
              currentAffect: const Pad(0.25, 0.35, 0.7), reason: 'calm'),
          isFalse);
      expect(c.state.version, 0);
      expect(c.trophyShelf, isEmpty);
      // Affect far from baselines: real, bounded movement.
      expect(
          c.tuneFromReflection(
              currentAffect: const Pad(0.85, 0.9, 0.95), reason: 'hot dream'),
          isTrue);
      expect(c.state.dominance, closeTo(0.725, 1e-9));
      expect(c.state.pleasure, lessThanOrEqualTo(0.25 + 0.15));
      expect(c.trophyShelf, isNotEmpty);
    });

    test('tuning reaches the live affect engine', () {
      final def = dannyDef();
      final c = DannyUpgradeController(def);
      c.applyChange('baseline_dominance', 0.78, reason: 'stand taller');
      final affect = AffectState(def);
      c.applyToAffect(affect);
      expect(affect.tunedBaseline, isNotNull);
      expect(affect.baseline.dominance, 0.78);
      expect(affect.effectiveTalkativeness, c.state.talkativeness);
    });

    test('state + log survive a save/boot round trip', () async {
      SharedPreferences.setMockInitialValues({});
      final def = dannyDef();
      final c = await DannyUpgradeController.boot(def);
      c.applyChange('baseline_arousal', 0.42, reason: 'persist me');
      await c.save();
      final restored = await DannyUpgradeController.boot(def);
      expect(restored.state.arousal, 0.42);
      expect(restored.state.version, 1);
      expect(restored.trophyShelf, hasLength(1));
    });
  });

  group('tone of voice', () {
    test('his prosody profile is his own, not the neutral uncast', () {
      final def = dannyDef();
      const pad = Pad(0.25, 0.35, 0.7);
      final his = Prosody.from(def.voice, pad);
      final neutral = Prosody.from(VoiceCasting.uncast, pad);
      expect(his.pitch, 0.92);
      expect(his.rate, isNot(neutral.rate));
      expect(his.stability, isNot(neutral.stability));
    });

    test('system prompt carries morals, guardrails and live tone', () {
      final def = dannyDef();
      final affect = AffectState(def);
      final agent = CharacterAgent(def: def, affect: affect);
      final prompt = agent.systemPrompt(unhinged: true);
      expect(prompt, contains('MORAL CORE:'));
      expect(prompt, contains('GUARDRAILS:'));
      expect(prompt, contains('WHAT YOU ARE:'));
      expect(prompt, contains('TONE OF VOICE:'));
      expect(prompt, contains('YOUR TONE RIGHT NOW'));
      expect(prompt,
          contains(def.toneByEmotion[affect.emotion.emotion]!));
      expect(prompt, contains('YOUR GIFTS:'));
      // And none of it leaks into another character's prompt.
      final raw = File('assets/characters.json').readAsStringSync();
      final doc = jsonDecode(raw) as Map<String, dynamic>;
      final dan = CharacterDef.fromJson((doc['characters'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .firstWhere((c) => c['id'] == 'dan'));
      final danPrompt = CharacterAgent(def: dan, affect: AffectState(dan))
          .systemPrompt(unhinged: true);
      expect(danPrompt, isNot(contains('MORAL CORE:')));
    });
  });

  group('the flagship chain', () {
    test('runs every stage in order and answers with the revision',
        () async {
      final def = dannyDef();
      final router = _ScriptedRouter();
      final registry = CharacterRegistry.parse(
          File('assets/characters.json').readAsStringSync());
      final affect = AffectState(def);
      final self = AgentSelf(def);
      final ledger = DannyLedger();
      final agent = CharacterAgent(
        def: def,
        affect: affect,
        self: self,
        namesById: {for (final c in registry.all) c.id: c.name},
        router: router,
      );
      final chain = DannyChain(
        router: router,
        thinker: Thinker(router: router),
        discernment: Discernment(_facts),
      );
      const userText =
          'Thanks — great work as always. Was the vault opened at 9?';
      final result = await chain.run(
        agent: agent,
        self: self,
        namesById: const {'danny': 'Danny'},
        userText: userText,
        unhinged: true,
        ledger: ledger,
      );
      expect(result.stages.map((s) => s.name),
          ['perceive', 'appraise', 'discern', 'draft', 'critique', 'revise', 'respond', 'reflect']);
      // Perceive is grounded in the real clock, not a canned line.
      expect(result.stages.first.detail, matches(RegExp(r'\d{2}:\d{2}')));
      // The revision is the reply; the draft never ships.
      expect(result.reply, contains('opened at 10'));
      expect(result.reply, isNot(contains('near enough')));
      expect(result.critique, contains('record contradicts'));
      // Discernment flagged the user's claim against the record.
      expect(
          result.discernment.any((c) =>
              c.verdict == DiscernmentVerdict.inconsistentWithFacts),
          isTrue);
      // Double-check really ran: four inference passes total
      // (think, draft, critique, revise).
      expect(router.prompts, hasLength(4));
      // Reflection wrote to the self-model and the ledger.
      expect(self.interactions, 1);
      expect(self.reflections, isNotEmpty);
      expect(ledger.gratitudeCount, greaterThanOrEqualTo(1));
      expect(ledger.entries.first.whoId, 'richard');
    });

    test('the discern stage reports through the Lie Detector: '
        'the statement is recorded and read out as verdict counts',
        () async {
      final def = dannyDef();
      final router = _ScriptedRouter();
      final registry = CharacterRegistry.parse(
          File('assets/characters.json').readAsStringSync());
      final affect = AffectState(def);
      final self = AgentSelf(def);
      final agent = CharacterAgent(
        def: def,
        affect: affect,
        self: self,
        namesById: {for (final c in registry.all) c.id: c.name},
        router: router,
      );
      final chain = DannyChain(
        router: router,
        thinker: Thinker(router: router),
        discernment: Discernment(_facts),
      );
      final result = await chain.run(
        agent: agent,
        self: self,
        namesById: const {'danny': 'Danny'},
        userText: 'Was the vault opened at 9?',
        unhinged: true,
      );
      // The detector readout rides the chain result: the vault
      // claim is contradicted by the record, counted in the
      // headline the discern stage reports.
      expect(result.lieReport, isNotNull);
      expect(result.lieReport!.contradictedCount, 1);
      expect(result.lieReport!.headline(), contains('1 contradicted'));
      final discern = result.stages.firstWhere((s) => s.name == 'discern');
      expect(discern.detail, contains('lie detector readout'));
      expect(discern.detail, contains('1 contradicted'));
    });

    test('the chain refuses to run for any other character', () async {
      final raw = File('assets/characters.json').readAsStringSync();
      final doc = jsonDecode(raw) as Map<String, dynamic>;
      final dan = CharacterDef.fromJson((doc['characters'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .firstWhere((c) => c['id'] == 'dan'));
      final chain = DannyChain(
          router: _ScriptedRouter(), discernment: Discernment(const []));
      await expectLater(
        chain.run(
          agent: CharacterAgent(def: dan, affect: AffectState(dan)),
          self: AgentSelf(dan),
          namesById: const {},
          userText: 'hello',
          unhinged: false,
        ),
        throwsArgumentError,
      );
    });
  });

  group('boot consistency (bug-sweep fix)', () {
    test('MindStore.boot also boots Danny\'s stores on every path',
        () async {
      SharedPreferences.setMockInitialValues({});
      DannyLedger.instance = null;
      DannyUpgradeController.instance = null;
      final registry = CharacterRegistry.parse(
          File('assets/characters.json').readAsStringSync());
      final mind = await MindStore.boot(registry);
      expect(DannyLedger.instance, isNotNull);
      expect(DannyUpgradeController.instance, isNotNull);
      expect(mind.affects.of('danny').character.id, 'danny');
    });
  });

  group('self-state report', () {
    test('every number comes from the live engines', () {
      final def = dannyDef();
      final affect = AffectState(def);
      final self = AgentSelf(def)..recordInteraction(DateTime.now());
      final upgrades = DannyUpgradeController(def)
        ..applyChange('volatility', 0.22, reason: 'report test');
      final report = DannySelfReport.build(
        def: def,
        affect: affect,
        self: self,
        ledger: DannyLedger(),
        upgrades: upgrades,
        unhinged: true,
      );
      expect(report, contains('SELF-STATE'));
      expect(report, contains('1 recorded interactions'));
      expect(report, contains('tuning at version 1'));
      expect(report, contains('1 verified upgrade'));
      expect(report, contains('UNCAST'));
      expect(report, contains('Ledger: empty'));
    });
  });
}

/// Scripted inference for the chain test: each stage's prompt has
/// a marker, and the script answers in character for that stage.
/// The draft deliberately repeats the wrong time so the
/// discernment + critique stages have something real to catch.
class _ScriptedRouter extends InferenceRouter {
  final List<String> prompts = [];

  @override
  Future<String> run(InferenceTask task, String prompt,
      {String? grammar}) async {
    prompts.add(prompt);
    if (prompt.contains('inner reasoning of Danny')) {
      return '{"situation":"Boss is asking about the vault",'
          '"feeling":"focused","memory":"The vault door was opened at 9",'
          '"goal":"answer with the record straight",'
          '"options":["trust it","check the record"],'
          '"chosen":"check the record","why":"receipts first"}';
    }
    if (prompt.contains('critical inner voice')) {
      return 'The draft repeats a time the record contradicts, '
          'and it hedges.';
    }
    if (prompt.contains('Your first draft was:')) {
      return 'Boss — the record says the vault door was opened '
          'at 10. Checked it. Twice.';
    }
    if (prompt.contains('Give your best first answer')) {
      return 'The vault was opened at 9, near enough.';
    }
    return 'scripted fallback';
  }
}
