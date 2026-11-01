import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rich_gang_ai/core/age_assurance.dart';
import 'package:rich_gang_ai/core/character.dart';
import 'package:rich_gang_ai/core/daemon_config.dart';
import 'package:rich_gang_ai/core/livekit_service.dart';
import 'package:rich_gang_ai/core/local_data_reset.dart';
import 'package:rich_gang_ai/core/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

CharacterDef _def({required bool gated, String status = 'configured'}) {
  return CharacterDef(
    id: gated ? 'gated' : 'open',
    name: gated ? 'Gated' : 'Open',
    displayName: gated ? 'Gated' : 'Open',
    title: 'Test',
    roles: const [CharacterRole.companion],
    core: 'test',
    personality: 'test',
    speechStyle: 'test',
    interests: const [],
    talkativeness: 0.5,
    volatility: 0.5,
    baselinePleasure: 0,
    baselineArousal: 0,
    baselineDominance: 0,
    ageGated: gated,
    voice: VoiceCasting.uncast,
    status: status,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AgeAssurance fail-closed boundary', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test(
        'no vendor configured means a stored adult record does not '
        'authorise a gated character', () async {
      await AgeAssurance.recordVerifiedForVendor(
        vendorId: 'vendor-test',
        vendorReference: 'opaque-test-reference',
        verifiedAt: DateTime.utc(2026, 10, 23),
      );
      final snapshot = await AgeAssurance.load();
      expect(snapshot.state, AgeAssuranceState.verifiedAdult);
      expect(snapshot.isAuthorised(_def(gated: true)), isFalse);
    });

    test(
        'vendor-configured snapshot authorises only from a real '
        'verified record', () async {
      await AgeAssurance.recordVerifiedForVendor(
        vendorId: 'vendor-test',
        vendorReference: 'opaque-test-reference',
        verifiedAt: DateTime.utc(2026, 10, 23),
      );
      final snapshot = await AgeAssurance.load(vendorConfigured: true);
      expect(snapshot.isAuthorised(_def(gated: true)), isTrue);
      expect(snapshot.isAuthorised(_def(gated: false)), isTrue);
    });

    test('malformed stored record is unavailable and locked', () async {
      SharedPreferences.setMockInitialValues({
        AgeAssurance.preferenceKey: 'not-json',
      });
      final snapshot = await AgeAssurance.load(vendorConfigured: true);
      expect(snapshot.state, AgeAssuranceState.unavailable);
      expect(snapshot.isAuthorised(_def(gated: true)), isFalse);
    });

    test('non-gated characters are never age-locked', () async {
      final snapshot = await AgeAssurance.load();
      expect(snapshot.isAuthorised(_def(gated: false)), isTrue);
    });
  });

  group('P6 daemon runtime config', () {
    test(
        'withStorePath preserves the asset config and sets the '
        'store path', () {
      final out = DaemonConfig.withStorePath(
        '{"personas":{"dan":{}}}',
        '/data/support/rich_gang_ai/daemon_store.sqlite3',
      );
      expect(out, contains('"personas"'));
      expect(
          out,
          contains('"store_path":"/data/support/rich_gang_ai/'
              'daemon_store.sqlite3"'));
      expect(
        DaemonConfig.storePathForSupportDir('/data/support'),
        '/data/support/rich_gang_ai/daemon_store.sqlite3',
      );
    });

    test('withStorePath rejects a malformed asset loudly', () {
      expect(() => DaemonConfig.withStorePath('not json', '/x.db'),
          throwsFormatException);
      expect(() => DaemonConfig.withStorePath('[1,2]', '/x.db'),
          throwsFormatException);
    });

    test(
        'the Kotlin dream handle reads the shared asset config '
        'and never boots "{}"', () {
      final kotlin = File('android/app/src/main/kotlin/com/richgang/ai/'
              'DreamCycleService.kt')
          .readAsStringSync();
      expect(kotlin, contains('loadSharedDaemonConfig'));
      expect(kotlin, contains('assets.open("daemon_config.json")'));
      expect(kotlin, contains('json.remove("store_path")'));
      expect(kotlin, isNot(contains('nativeBoot("{}")')));
    });

    test(
        'main boots the daemon with the runtime config and '
        'writes the store provenance record', () {
      final main = File('lib/main.dart').readAsStringSync();
      expect(main, contains('DaemonConfig.withStorePath'));
      expect(main, contains('DaemonConfig.provenanceSchemaKey'));
      expect(main, contains('DaemonConfig.provenanceBootKey'));
    });
  });

  group('P7 security surfaces', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('LocalDataReset inventory matches the real stored keys', () {
      expect(LocalDataReset.isLocalDataKey('mind_store_v1'), isTrue);
      expect(LocalDataReset.isLocalDataKey('danny_ledger_v1'), isTrue);
      expect(LocalDataReset.isLocalDataKey('danny_upgrades_v1'), isTrue);
      expect(LocalDataReset.isLocalDataKey('lie_detector_v1'), isTrue);
      expect(LocalDataReset.isLocalDataKey('age_assurance_v1'), isTrue);
      expect(LocalDataReset.isLocalDataKey('age_21_confirmed'), isTrue);
      expect(LocalDataReset.isLocalDataKey('liveavatar_avatar_dan'), isTrue);
      expect(LocalDataReset.isLocalDataKey('heygen_avatar_dan'), isTrue);
      expect(LocalDataReset.isLocalDataKey('avatar3d_src_dan'), isTrue);
      expect(LocalDataReset.isLocalDataKey('unrelated_key'), isFalse);
    });

    test('clearPreferences removes only inventoried keys', () async {
      SharedPreferences.setMockInitialValues({
        'mind_store_v1': 'x',
        'age_21_confirmed': true,
        'liveavatar_context_dan': 'ctx',
        'unrelated_key': 'keep',
      });
      final removed = await LocalDataReset.clearPreferences();
      expect(removed, 3);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('mind_store_v1'), isNull);
      expect(prefs.getString('unrelated_key'), 'keep');
    });

    test(
        'LiveKit token source: a configured server endpoint '
        'takes precedence and the secret is never read', () async {
      final settings = AppSettings.instance;
      final oldEndpoint = settings.liveKitTokenEndpoint;
      settings.liveKitTokenEndpoint = 'https://tokens.example.invalid/mint';
      addTearDown(() => settings.liveKitTokenEndpoint = oldEndpoint);
      final service = LiveKitService(
        tokenFetcher: ({
          required Uri endpoint,
          required String roomName,
          required String identity,
        }) async =>
            'server-token-for-$roomName/$identity',
      );
      expect(service.resolveTokenSource(), LiveKitTokenSource.server);
      expect(
        await service.obtainToken(roomName: 'room1', identity: 'richard'),
        'server-token-for-room1/richard',
      );
      settings.liveKitTokenEndpoint = '';
      expect(service.resolveTokenSource(), LiveKitTokenSource.onDevice);
    });

    test(
        'Settings carries remove-key controls, orphan labels, '
        'the privacy surface and the SEC-01 copy', () {
      final settings = File('lib/views/settings_view.dart').readAsStringSync();
      expect(settings, contains('Remove NVIDIA key'));
      expect(settings, contains('Remove ElevenLabs key'));
      expect(settings, contains('Remove HeyGen key'));
      expect(settings, contains('Remove LiveAvatar key'));
      expect(settings, contains('Remove all API keys'));
      expect(settings, contains('Reset local data'));
      expect(settings, contains('NOT WIRED IN THIS BUILD'));
      expect(settings, contains('Privacy — what leaves this device'));
      expect(settings, contains('liveKitTokenEndpoint'));
      expect(settings, contains('private-build risk (SEC-01)'));
    });

    test('backup behaviour is explicit in the manifest and rules', () {
      final manifest =
          File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      expect(manifest, contains('android:fullBackupContent'));
      expect(manifest, contains('android:dataExtractionRules'));
      final rules = File('android/app/src/main/res/xml/backup_rules.xml')
          .readAsStringSync();
      expect(rules, contains('<exclude domain="sharedpref"'));
      expect(rules, contains('daemon_store.sqlite3'));
      final extraction =
          File('android/app/src/main/res/xml/data_extraction_rules.xml')
              .readAsStringSync();
      expect(extraction, contains('<device-transfer>'));
      expect(extraction, contains('<exclude domain="sharedpref"'));
    });
  });

  group('Flagship sweep source locks', () {
    String read(String path) => File(path).readAsStringSync();

    test(
        'age enforcement exists at chat, call, stage, picker, room '
        'and roundtable', () {
      expect(read('lib/views/character_chat_view.dart'),
          contains('AgeAssurance.load()'));
      expect(read('lib/views/character_chat_view.dart'),
          contains('21+ character locked'));
      expect(read('lib/views/avatar_call_view.dart'),
          contains('AgeAssurance.load()'));
      expect(read('lib/views/avatar_stage_view.dart'),
          contains('_refreshFocusedAge'));
      expect(read('lib/views/character_picker.dart'),
          contains('AgeGate.ensureAuthorised'));
      expect(read('lib/views/the_room.dart'),
          contains('AgeGate.ensureAuthorised'));
      expect(read('lib/views/roundtable_view.dart'),
          contains('AgeGate.isAuthorised'));
      expect(read('lib/core/character_agent.dart'),
          isNot(contains('behind a verified 21+')));
    });

    test(
        'roundtable defaults to configured characters and collapses '
        'setup while running', () {
      final view = read('lib/views/roundtable_view.dart');
      expect(view, contains('All configured'));
      expect(view, contains('(not configured)'));
      expect(view, contains('_sessionBar(session)'));
      expect(view, contains('Check Settings'));
      expect(view, contains('Start again'));
    });

    test(
        'call view has preflight and keeps IDs and logs in advanced '
        'sections', () {
      final view = read('lib/views/avatar_call_view.dart');
      expect(view, contains('_preflightCard()'));
      expect(view, contains('Advanced & IDs'));
      expect(view, contains('Diagnostics'));
      expect(view, contains('HeyGen (disabled)'));
    });

    test('tab state is preserved with IndexedStack', () {
      expect(read('lib/app_scaffold.dart'),
          contains('IndexedStack(index: _index'));
    });
  });
}
