import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:rich_gang_ai/core/livekit_service.dart';

Map<String, dynamic> _decodePart(String part) {
  final padded = part.padRight(part.length + (4 - part.length % 4) % 4, '=');
  return jsonDecode(utf8.decode(base64Url.decode(padded)))
      as Map<String, dynamic>;
}

void main() {
  test('minted LiveKit token has the verified JWT shape and grants', () {
    final token = mintLiveKitToken(
      apiKey: 'APIxxxxxxxx',
      apiSecret: 'test-secret',
      identity: 'richard',
      room: 'crew-link',
      ttl: const Duration(hours: 1),
    );
    final parts = token.split('.');
    expect(parts.length, 3, reason: 'JWT must be header.payload.signature');

    final header = _decodePart(parts[0]);
    expect(header['alg'], 'HS256');
    expect(header['typ'], 'JWT');

    final payload = _decodePart(parts[1]);
    expect(payload['iss'], 'APIxxxxxxxx');
    expect(payload['sub'], 'richard');
    expect((payload['exp'] as int) - (payload['nbf'] as int), 3600);
    final video = payload['video'] as Map<String, dynamic>;
    expect(video['roomJoin'], isTrue);
    expect(video['room'], 'crew-link');
    expect(video['canPublish'], isTrue);
    expect(video['canSubscribe'], isTrue);

    // Signature must differ when the secret differs (HMAC is real,
    // not a constant suffix).
    final other = mintLiveKitToken(
      apiKey: 'APIxxxxxxxx',
      apiSecret: 'other-secret',
      identity: 'richard',
      room: 'crew-link',
      ttl: const Duration(hours: 1),
    );
    expect(other.split('.')[2], isNot(parts[2]));
  });
}
