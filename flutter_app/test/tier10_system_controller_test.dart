import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rich_gang_ai/core/character.dart';
import 'package:rich_gang_ai/core/tier10_system_controller.dart';
import 'package:rich_gang_ai/views/tier10_hud.dart';
import 'package:flutter/material.dart';

void main() {
  group('Tier10SystemController', () {
    test('starts cloud-synchronized with NO measured latency', () {
      final c = Tier10SystemController(activeAgentsCount: 2);
      expect(c.currentState, Tier10ExecutionState.cloudSynchronized);
      // Unmeasured is null — never an invented 12.4 / 1.2.
      expect(c.latencyMs, isNull);
      expect(c.failureCount, 0);
      expect(c.activeAgentsCount, 2);
    });

    test('agent count comes from the registry, not a literal', () {
      const fixture = '''
{"characters":[
 {"id":"a","name":"A","display_name":"A","title":"T",
  "roles":[],"core":"c","personality":"p","speech_style":"s",
  "interests":[],"talkativeness":0.5,"volatility":0.5,
  "baseline":{"pleasure":0.0,"arousal":0.0,"dominance":0.0},
  "age_gated":false,
  "voice":{"display":"V","eleven_labs_voice_id":"x",
   "eleven_labs_voice_name":"N","kokoro_voice":"k",
   "system_pitch":1.0,"system_rate":0.5,"stability":0.5,"style":0.3}},
 {"id":"b","name":"B","display_name":"B","title":"T2",
  "status":"registry_only_unconfigured","age_gated":true}
]}''';
      final registry = CharacterRegistry.parse(fixture);
      final c = Tier10SystemController.fromRegistry(registry);
      expect(c.activeAgentsCount, registry.all.length);
      c.updateAgentCount(5);
      expect(c.activeAgentsCount, 5);
    });

    test('measured success records the real latency', () {
      final c = Tier10SystemController();
      c.recordCloudSuccess(const Duration(milliseconds: 123));
      expect(c.latencyMs, closeTo(123.0, 0.001));
      expect(c.failureCount, 0);
      expect(c.currentState, Tier10ExecutionState.cloudSynchronized);
    });

    test('failures trip to edge only at the threshold', () {
      final c = Tier10SystemController(failureThreshold: 3);
      c.recordCloudFailure(StateError('boom'));
      c.recordCloudFailure(StateError('boom'));
      expect(c.currentState, Tier10ExecutionState.cloudSynchronized);
      c.recordCloudFailure(StateError('boom'));
      expect(c.currentState, Tier10ExecutionState.sovereignEdgeActive);
      expect(c.failureCount, 3);
      expect(c.lastError, isA<StateError>());
    });

    test('latency above 250ms counts as a failure signal', () {
      final c = Tier10SystemController(failureThreshold: 2);
      c.recordCloudSuccess(const Duration(milliseconds: 900));
      expect(c.latencyMs, closeTo(900.0, 0.001));
      expect(c.failureCount, 1);
      c.recordCloudSuccess(const Duration(milliseconds: 300));
      expect(c.currentState, Tier10ExecutionState.sovereignEdgeActive);
    });

    test('recovery probe: success in failoverTesting restores cloud',
        () {
      final c = Tier10SystemController(failureThreshold: 1);
      c.recordCloudFailure(StateError('down'));
      expect(c.currentState, Tier10ExecutionState.sovereignEdgeActive);
      c.beginRecoveryProbe();
      expect(c.currentState, Tier10ExecutionState.failoverTesting);
      c.recordCloudSuccess(const Duration(milliseconds: 40));
      expect(c.currentState, Tier10ExecutionState.cloudSynchronized);
      expect(c.failureCount, 0);
    });

    test('failure during a probe returns to edge; restoreCloud resets',
        () {
      final c = Tier10SystemController(failureThreshold: 5);
      c.tripToEdge();
      c.beginRecoveryProbe();
      c.recordCloudFailure(StateError('still down'));
      expect(c.currentState, Tier10ExecutionState.sovereignEdgeActive);
      c.restoreCloud();
      expect(c.currentState, Tier10ExecutionState.cloudSynchronized);
      expect(c.failureCount, 0);
      expect(c.lastError, isNull);
    });

    test('beginRecoveryProbe is a no-op from cloud state', () {
      final c = Tier10SystemController();
      c.beginRecoveryProbe();
      expect(c.currentState, Tier10ExecutionState.cloudSynchronized);
    });
  });

  group('expanded characters.json (real asset file)', () {
    // Read the shipped asset directly — no total is hardcoded as a
    // magic expectation: the assertions are per-id and per-status,
    // so adding a future agent updates counts by construction.
    final raw = File('assets/characters.json').readAsStringSync();
    final registry = CharacterRegistry.parse(raw);
    final doc = jsonDecode(raw) as Map<String, dynamic>;

    const originalNine = [
      'dan',
      'rich',
      'crazy_kelly',
      'freddy',
      'tammy',
      'sally',
      'leo',
      'capricorn',
      'aquarius',
    ];
    // Danny was promoted out of the registry-only tier on
    // 2026-10-23 (flagship model — see roster_asset_test.dart and
    // danny_flagship_test.dart). He is counted separately so this
    // file's totals stay true: 9 original + Danny + 13 expansion.
    const flagship = ['danny'];
    const expansion = [
      'rich_rich',
      'richard',
      'mustang',
      'wickos',
      'shawna',
      'ruby',
      'iron_outlaw',
      'empress',
      'wildcard',
      'oracle',
      'archivist',
      'tom',
      'caesar',
    ];
    // WTF Zone multiverse merge, 2026-10-25 (Richard's direction):
    // 19 registry-only entries from the WTF Zone, Twilight Zone,
    // Freak Show, Neon-Beach, and Anime parallels.
    const multiverse = [
      'carl',
      'babs',
      'undra',
      'buck_chatt',
      'ricco_chain',
      'houston_cole',
      'verso_marlowe',
      'jinx_malone',
      'jack_thrill',
      'mister_smoke',
      'cel',
      'chrome_grin',
      'pearl',
      'sterling_blake',
      'asher_grey',
      'gilda_gaze',
      'madame_dryer',
      'mop',
      'octavia_shears',
    ];

    test('every supplied id loads exactly once', () {
      for (final id in [
        ...originalNine,
        ...flagship,
        ...expansion,
        ...multiverse,
      ]) {
        expect(registry.byId(id), isNotNull, reason: id);
      }
      expect(
          registry.all.length,
          originalNine.length +
              flagship.length +
              expansion.length +
              multiverse.length);
    });

    test('Danny leads the roster in the flagship tier', () {
      final danny = registry.byId('danny')!;
      expect(registry.all.first.id, 'danny');
      expect(danny.status, 'configured_voice_uncast');
      expect(danny.isRegistryOnly, isFalse);
      expect(danny.portrait, isNotNull);
      // Still honestly uncast — promotion invented no voice id.
      expect(danny.voice.isUncast, isTrue);
    });

    test('original nine retain portrait, voice casting and zodiac', () {
      const zodiac = {
        'rich': 'Aries',
        'crazy_kelly': 'Taurus', // resolved 2026-10-22 at Richard's decision: Crazy Kelly stays (Cougar dropped), takes the #2 slot zodiac Taurus; Dan keeps Scorpio alone
        'freddy': 'Cancer',
        'tammy': 'Leo',
        'sally': 'Virgo',
        'dan': 'Scorpio',
        'aquarius': 'Sagittarius',
        'leo': 'Capricorn',
        'capricorn': 'Aquarius',
      };
      for (final id in originalNine) {
        final c = registry.byId(id)!;
        expect(c.isRegistryOnly, isFalse, reason: id);
        expect(c.portrait, isNotNull, reason: id);
        expect(c.voice.isUncast, isFalse, reason: id);
        expect(c.voice.elevenLabsVoiceId, isNotEmpty, reason: id);
        expect(c.zodiac, zodiac[id], reason: id);
      }
    });

    test('expansion entries are registry-only and honestly uncast',
        () {
      for (final id in expansion) {
        final c = registry.byId(id)!;
        expect(c.status, 'registry_only_unconfigured', reason: id);
        expect(c.isRegistryOnly, isTrue, reason: id);
        expect(c.portrait, isNull, reason: id);
        expect(c.voice.isUncast, isTrue, reason: id);
        expect(c.zodiacOrCelestial, isNotNull, reason: id);
      }
      // The raw JSON must not smuggle in invented configuration:
      // no portrait/voice/baseline keys on expansion entries at all.
      final chars = (doc['characters'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      for (final j in chars.where((j) => expansion.contains(j['id']))) {
        expect(j.containsKey('portrait'), isFalse, reason: '${j['id']}');
        expect(j.containsKey('voice'), isFalse, reason: '${j['id']}');
        expect(j.containsKey('baseline'), isFalse, reason: '${j['id']}');
      }
    });

    test('age gates: only Kelly, Shawna and Ruby', () {
      expect(registry.byId('crazy_kelly')!.ageGated, isTrue);
      expect(registry.byId('shawna')!.ageGated, isTrue);
      expect(registry.byId('ruby')!.ageGated, isTrue);
      for (final c in registry.all) {
        if (['crazy_kelly', 'shawna', 'ruby'].contains(c.id)) continue;
        expect(c.ageGated, isFalse, reason: c.id);
      }
    });

    test('Tammy keeps her title; the Nocturna oracle is distinct', () {
      // Resolved 2026-10-22 at Richard's instruction ("fix what
      // needs"), same pattern as the Kelly fix: Tammy — configured,
      // from Richard's original frames — keeps the title
      // "The Oracle" untouched. The registry-only Nocturna entry is
      // qualified by its universe so the two never share a name:
      // she is "The Oracle of Nocturna", title "Nocturna Dream
      // Analyst". No personal name was invented for her.
      expect(registry.byId('tammy')!.title, 'The Oracle');
      final oracle = registry.byId('oracle')!;
      expect(oracle.name, 'The Oracle of Nocturna');
      expect(oracle.title, 'Nocturna Dream Analyst');
      expect(oracle.universe, 'Nocturna');
    });

    test('daemon_config personas match the registry ids', () {
      final cfg = jsonDecode(
              File('assets/daemon_config.json').readAsStringSync())
          as Map<String, dynamic>;
      final personas = (cfg['personas'] as List<dynamic>).cast<String>();
      expect(personas.toSet(), registry.all.map((c) => c.id).toSet());
      expect(personas.length, registry.all.length);
    });
  });

  group('registry-only parser safety (fixture)', () {
    test('missing voice/baseline/portrait parse without crashing',
        () {
      const fixture = '''
{"characters":[
 {"id":"bare","name":"Bare","display_name":"Bare","title":"Role Line",
  "status":"registry_only_unconfigured","age_gated":false,
  "zodiac":"Gemini","core":"Role Line","personality":"Role Line",
  "speech_style":"Role Line"}
]}''';
      final bare = CharacterRegistry.parse(fixture).byId('bare')!;
      expect(bare.portrait, isNull);
      expect(bare.voice.isUncast, isTrue);
      expect(bare.baselinePleasure, 0.0);
      expect(bare.isRegistryOnly, isTrue);
      expect(bare.zodiac, 'Gemini');
    });
  });

  group('Tier10Hud widget', () {
    testWidgets('shows unmeasured latency honestly', (tester) async {
      final c = Tier10SystemController(activeAgentsCount: 3);
      await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: Tier10Hud(controller: c))));
      expect(find.textContaining('not measured yet'), findsOneWidget);
      expect(find.textContaining('Cloud Synchronized'), findsOneWidget);
      c.recordCloudSuccess(const Duration(milliseconds: 42));
      await tester.pump();
      expect(find.textContaining('42.0 ms'), findsOneWidget);
    });
  });
}
