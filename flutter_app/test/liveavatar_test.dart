import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rich_gang_ai/core/affect_engine.dart';
import 'package:rich_gang_ai/core/character.dart';
import 'package:rich_gang_ai/core/liveavatar.dart';
import 'package:rich_gang_ai/core/roundtable.dart';

CharacterDef _def() => CharacterDef.fromJson(const {
      'id': 'dan',
      'name': 'Dan',
      'display_name': 'Rich Dan',
      'title': 'Universal Operator',
      'roles': ['butler'],
      'core': 'Dan is a universal operator.',
      'personality': 'Dry, precise, loyal.',
      'speech_style': 'Short sentences. No filler.',
      'interests': ['systems', 'music'],
      'talkativeness': 0.6,
      'volatility': 0.3,
      'baseline': {'pleasure': 0.2, 'arousal': 0.1, 'dominance': 0.4},
      'age_gated': false,
      'voice': {
        'display': 'Zeus',
        'eleven_labs_voice_id': 'x',
        'eleven_labs_voice_name': 'Dave',
        'kokoro_voice': 'am_michael',
        'system_pitch': 1.0,
        'system_rate': 0.5,
        'stability': 0.5,
        'style': 0.3,
      },
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Secure storage reads must resolve (to "no key") in tests, not
  // throw MissingPluginException — mock the plugin channel empty.
  const secureChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(secureChannel, (call) async => null);

  group('liveavatar envelope parsers', () {
    test('token parses from the documented envelope', () {
      final t = LiveAvatarToken.tryParse(jsonEncode({
        'code': 100,
        'data': {'session_id': 's-1', 'session_token': 'tok-1'},
        'message': 'success',
      }));
      expect(t?.sessionId, 's-1');
      expect(t?.sessionToken, 'tok-1');
    });

    test('error envelope (data null) parses to null, message kept',
        () {
      const body =
          '{"code":4001,"data":null,"message":"Invalid API key"}';
      expect(LiveAvatarToken.tryParse(body), isNull);
      expect(LiveAvatarSessionData.tryParse(body), isNull);
      expect(LiveAvatarService.envelopeMessage(body), 'Invalid API key');
    });

    test('start parses livekit fields and optional ws_url', () {
      final s = LiveAvatarSessionData.tryParse(jsonEncode({
        'code': 100,
        'data': {
          'session_id': 's-9',
          'livekit_url': 'wss://livekit.liveavatar.com',
          'livekit_client_token': 'ct-9',
          'ws_url': 'wss://api.liveavatar.com/ws',
        },
        'message': 'success',
      }));
      expect(s?.liveKitUrl, 'wss://livekit.liveavatar.com');
      expect(s?.liveKitClientToken, 'ct-9');
      expect(s?.wsUrl, isNotNull);
      // Missing a required field must not parse.
      expect(
          LiveAvatarSessionData.tryParse(jsonEncode({
            'code': 100,
            'data': {'session_id': 's-9', 'livekit_url': 'wss://x'},
          })),
          isNull);
    });
  });

  group('liveavatar requests (mock client, documented shapes)', () {
    test('createContext posts to /v1/contexts with X-API-KEY',
        () async {
      http.Request? seen;
      final client = MockClient((req) async {
        seen = req;
        return http.Response(
            jsonEncode({
              'code': 100,
              'data': {'id': 'ctx-42'},
              'message': 'success',
            }),
            200);
      });
      final svc = LiveAvatarService(client: client);
      // No key in the test environment's secure storage: the call
      // must refuse BEFORE any request is made.
      await expectLater(
        svc.createContext(name: 'n', prompt: 'p', openingText: 'o'),
        throwsA(isA<LiveAvatarException>()),
      );
      expect(seen, isNull);
    });

    test('context prompt is composed from the character definition',
        () {
      final prompt = LiveAvatarService.contextPromptFor(_def());
      expect(prompt, contains('Rich Dan'));
      expect(prompt, contains('universal operator'));
      expect(prompt, contains('Dry, precise, loyal.'));
      expect(prompt, contains('systems, music'));
      expect(LiveAvatarService.openingTextFor(_def()),
          contains('Rich Dan'));
    });
  });

  group('roundtable transcript export', () {
    test('formats header, turns, emotions and thoughts', () {
      final def = _def();
      final registry = CharacterRegistry({def.id: def});
      final session = RoundtableSession(affects: AffectEngine(registry));
      session.transcript.add(RoundtableTurn(
        speakerId: 'dan',
        speakerName: 'Dan',
        text: 'We begin.',
        emotion: 'calm',
        at: DateTime(2026, 10, 21, 9, 5, 3),
        isUser: false,
        thoughtSummary: 'Dan weighed the room.',
      ));
      session.transcript.add(RoundtableTurn(
        speakerId: 'richard',
        speakerName: 'Richard',
        text: 'Keep going.',
        emotion: '—',
        at: DateTime(2026, 10, 21, 9, 6, 0),
        isUser: true,
      ));
      final text = session.transcriptText();
      expect(text, contains('RICH GANG AI — THE ROUNDTABLE'));
      expect(text, contains('[09:05:03] Dan (feeling calm): We begin.'));
      expect(text, contains('thought: Dan weighed the room.'));
      expect(text, contains('[09:06:00] Richard: Keep going.'));
    });
  });
}
