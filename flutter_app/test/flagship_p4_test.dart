import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Flagship P4 regression locks (Tranche 1, 2026-10-23).
///
/// These are source-surface locks in the same style as the roster
/// locks: the production Room must not regain a manual thermal
/// simulation control or the static NEXUS chip strip, and the
/// Tier-10 HUD must not describe its registry total as if it were
/// a ready-agent count or claim it is unwired when The Room mounts
/// it.
void main() {
  test('The Room has no production test-thermal control or NEXUS strip',
      () {
    final room = File('lib/views/the_room.dart').readAsStringSync();
    expect(room, isNot(contains('Test thermal severe')));
    expect(room, isNot(contains('NEXUS — SYSTEM NODES')));
    expect(room, isNot(contains("Chip(label: Text('QUANTUM'))")));
    expect(room, isNot(contains("Chip(label: Text('MARKET'))")));
    expect(room, isNot(contains("Chip(label: Text('VIDEO•GEN'))")));
  });

  test('Tier10Hud header and count label match its mounted reality', () {
    final hud = File('lib/views/tier10_hud.dart').readAsStringSync();
    expect(hud, contains('mounted by'));
    expect(hud, isNot(contains('Deliberately NOT wired')));
    expect(hud, contains('Configured characters:'));
    expect(hud, contains('Registry-only:'));
    expect(hud, contains('Total:'));
  });

  test('The Room separates configured cast from registry-only entries',
      () {
    final room = File('lib/views/the_room.dart').readAsStringSync();
    expect(room, contains('THE CAST — CONFIGURED CHARACTERS'));
    expect(room, contains('REGISTRY — NOT CONFIGURED'));
    expect(room, contains('_configuredCastGrid'));
    expect(room, contains('_registryOnlySection'));
    expect(room, contains('VOICE UNCAST — SYSTEM TTS'));
    expect(room, contains('key saved (unverified)'));
  });

  test('unreachable standalone chat console is removed', () {
    expect(File('lib/views/chat_console_view.dart').existsSync(), isFalse);
  });

  test('P4 re-audit 2026-10-30: Room actions label demo/BYO state honestly',
      () {
    final room = File('lib/views/the_room.dart').readAsStringSync();
    expect(room, contains('3D Stage (Demo Preview)'));
    expect(room, isNot(contains("label: const Text('3D Avatar Stage')")));
    expect(room, contains('Interrogate (BYO Scene)'));
    // Setup rows: a saved-but-unverified key never gets the check
    // icon, and the voice row marks the working system-TTS fallback.
    expect(room, contains('unverified:'));
    expect(room, contains('Voice always works via system TTS'));
  });

  test('P4 disposition 2026-10-30: demo/BYO surfaces live in Labs, '
      'not as flagship actions', () {
    final room = File('lib/views/the_room.dart').readAsStringSync();
    expect(room, contains('LABS — PREVIEW SURFACES'));
    expect(room, contains('Previews only.'));
    // The Stage must not be a full-width primary FilledButton anymore.
    expect(room,
        isNot(contains("child: FilledButton.icon(\n              onPressed: "
            "() => Navigator.of(context).push(\n                MaterialPageRoute<void>(\n                    "
            "builder: (_) => const AvatarStageView())")));
  });

  test('P4 enhance 2026-10-31: chat header is portrait-forward and '
      'states voice truth', () {
    final chat = File('lib/views/character_chat_view.dart').readAsStringSync();
    expect(chat, contains('CharacterAvatar(def: def, radius: 26)'));
    expect(chat, contains('VOICE UNCAST — SYSTEM TTS'));
    expect(chat, isNot(contains('CharacterAvatar(def: def, radius: 16)')));
  });

  test('P4 re-audit 2026-10-30: chat failure is an error card, not a line',
      () {
    final chat = File('lib/views/character_chat_view.dart').readAsStringSync();
    expect(chat, contains('_lastError'));
    expect(chat, contains("label: const Text('Retry')"));
    expect(chat, contains("label: const Text('Open Settings')"));
    expect(chat, isNot(contains('System: inference unavailable')));
    expect(chat, isNot(contains("?? 'loading'")));
    expect(chat, isNot(contains('Video / voice call (HeyGen avatar)')));
  });

  test('P4 re-audit 2026-10-30: HeyGen legacy stays unselectable', () {
    final call = File('lib/views/avatar_call_view.dart').readAsStringSync();
    expect(call, contains("label: Text('HeyGen (disabled)')"));
    expect(call, contains('enabled: false'));
  });
}
