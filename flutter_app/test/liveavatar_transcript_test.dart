import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rich_gang_ai/core/liveavatar.dart';

/// LiveAvatar transcript wiring locks (2026-10-30): the fetch uses
/// the documented GET /v1/sessions/{session_id}/transcript shape
/// (X-API-KEY, {code, data:{transcript_data:[{role, transcript,
/// absolute_timestamp, relative_timestamp}], next_timestamp}}),
/// returns only lines the API returned in order, drops unusable
/// lines instead of inventing them, follows next_timestamp
/// pagination, and refuses before any request when no key is
/// stored. No live call is made here — all responses are mocks
/// shaped exactly like the documented OpenAPI response, and the
/// secure-storage channel is mocked to return a test key.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const secureChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  Future<void> mockKey(String? key) async {
    messenger.setMockMethodCallHandler(secureChannel, (call) async {
      if (call.method == 'read') return key;
      return null;
    });
  }

  setUp(() async {
    await mockKey('test-key');
  });

  Map<String, dynamic> envelope(List<Map<String, dynamic>> lines,
          {int? nextTimestamp}) =>
      {
        'code': 100,
        'data': {
          'session_active': false,
          if (nextTimestamp != null) 'next_timestamp': nextTimestamp,
          'transcript_data': lines,
        },
        'message': 'success',
      };

  test('fetches user and avatar lines in order, seconds timestamps',
      () async {
    http.Request? seen;
    final client = MockClient((req) async {
      seen = req;
      return http.Response(
          jsonEncode(envelope([
            {
              'role': 'user',
              'transcript': 'Hello there.',
              'absolute_timestamp': 1761840000,
              'relative_timestamp': 5,
            },
            {
              'role': 'avatar',
              'transcript': 'Good to see you.',
              'absolute_timestamp': 1761840003,
              'relative_timestamp': 8,
            },
          ])),
          200);
    });
    final lines =
        await LiveAvatarService(client: client).fetchTranscript('s-1');
    expect(seen?.method, 'GET');
    expect(seen?.url.path, '/v1/sessions/s-1/transcript');
    expect(seen?.headers['X-API-KEY'], 'test-key');
    expect(lines.map((l) => l.role).toList(), ['user', 'avatar']);
    expect(lines.map((l) => l.text).toList(),
        ['Hello there.', 'Good to see you.']);
    expect(
        lines[0].at,
        DateTime.fromMillisecondsSinceEpoch(1761840000 * 1000,
            isUtc: true));
  });

  test('follows next_timestamp pagination with start_timestamp',
      () async {
    final seenUrls = <Uri>[];
    var calls = 0;
    final client = MockClient((req) async {
      seenUrls.add(req.url);
      calls++;
      if (calls == 1) {
        return http.Response(
            jsonEncode(envelope(
              [
                {
                  'role': 'user',
                  'transcript': 'First.',
                  'absolute_timestamp': 1761840000,
                  'relative_timestamp': 1,
                },
              ],
              nextTimestamp: 999,
            )),
            200);
      }
      return http.Response(
          jsonEncode(envelope([
            {
              'role': 'avatar',
              'transcript': 'Second.',
              'absolute_timestamp': 1761840002,
              'relative_timestamp': 3,
            },
          ])),
          200);
    });
    final lines =
        await LiveAvatarService(client: client).fetchTranscript('s-2');
    expect(calls, 2);
    expect(seenUrls[1].queryParameters['start_timestamp'], '999');
    expect(lines.map((l) => l.text).toList(), ['First.', 'Second.']);
  });

  test('millisecond absolute timestamps parse as milliseconds',
      () async {
    final client = MockClient((req) async => http.Response(
        jsonEncode(envelope([
          {
            'role': 'avatar',
            'transcript': 'Ms time.',
            'absolute_timestamp': 1761840003000,
            'relative_timestamp': 8000,
          },
        ])),
        200));
    final lines =
        await LiveAvatarService(client: client).fetchTranscript('s-3');
    expect(
        lines.single.at,
        DateTime.fromMillisecondsSinceEpoch(1761840003000,
            isUtc: true));
  });

  test('refuses before any request when no key is stored', () async {
    await mockKey(null);
    http.Request? seen;
    final client = MockClient((req) async {
      seen = req;
      return http.Response('{}', 200);
    });
    await expectLater(
      LiveAvatarService(client: client).fetchTranscript('s-4'),
      throwsA(isA<LiveAvatarException>()),
    );
    expect(seen, isNull);
  });

  test('a response with no transcript_data is an error, not an '
      'empty success', () async {
    final client = MockClient((req) async => http.Response(
        jsonEncode({
          'code': 100,
          'data': {'session_active': false},
          'message': 'success',
        }),
        200));
    await expectLater(
      LiveAvatarService(client: client).fetchTranscript('s-5'),
      throwsA(isA<LiveAvatarException>()),
    );
  });

  test('drops lines with an unknown role or empty text, never '
      'repairs them', () {
    expect(
        LiveAvatarTranscriptLine.tryParse({
          'role': 'system',
          'transcript': 'Nope.',
          'absolute_timestamp': 1761840000,
          'relative_timestamp': 1,
        }),
        isNull);
    expect(
        LiveAvatarTranscriptLine.tryParse({
          'role': 'user',
          'transcript': '',
          'absolute_timestamp': 1761840000,
          'relative_timestamp': 1,
        }),
        isNull);
    expect(LiveAvatarTranscriptLine.tryParse('not a map'), isNull);
  });

  test('falls back to start time plus relative offset when the '
      'absolute timestamp is unusable', () {
    final started = DateTime.utc(2026, 10, 30, 20, 0);
    final line = LiveAvatarTranscriptLine.tryParse(
      {
        'role': 'user',
        'transcript': 'Still here.',
        'absolute_timestamp': 42,
        'relative_timestamp': 30,
      },
      sessionStartedAt: started,
    )!;
    expect(line.at, started.add(const Duration(seconds: 30)));
  });
}
