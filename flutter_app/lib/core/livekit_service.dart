import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:livekit_client/livekit_client.dart';
import 'secure_keys.dart';
import 'settings.dart';

/// Where a Crew Link access token came from.
enum LiveKitTokenSource { server, onDevice }

/// Fetches a server-minted token: POST {"room": ..., "identity":
/// ...} to [endpoint], expecting a 2xx JSON body {"token": ...}.
/// Any other shape is an explicit error — never a silent fallback
/// to on-device minting.
typedef LiveKitTokenFetcher = Future<String> Function({
  required Uri endpoint,
  required String roomName,
  required String identity,
});

Future<String> fetchServerMintedLiveKitToken({
  required Uri endpoint,
  required String roomName,
  required String identity,
  http.Client? client,
}) async {
  final ownClient = client == null;
  final c = client ?? http.Client();
  try {
    final response = await c.post(
      endpoint,
      headers: const {'content-type': 'application/json'},
      body: jsonEncode({'room': roomName, 'identity': identity}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
          'LiveKit token endpoint returned HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body);
    final token = decoded is Map<String, dynamic> ? decoded['token'] : null;
    if (token is! String || token.isEmpty) {
      throw const FormatException(
          'LiveKit token endpoint response has no "token" string');
    }
    return token;
  } finally {
    if (ownClient) c.close();
  }
}

/// LiveKit access-token minting (JWT, HS256), done on-device.
///
/// Token shape VERIFIED against LiveKit's server SDK sources:
/// header {"alg":"HS256","typ":"JWT"}; claims {"iss": apiKey,
/// "sub": identity, "name": identity, "nbf": now, "exp": now + ttl,
/// "video": {"roomJoin": true, "room": room, "canPublish": true,
/// "canSubscribe": true, "canPublishData": true}}; signature is
/// HMAC-SHA256 over base64url(header).base64url(payload) with the
/// API secret.
///
/// SECURITY NOTE, stated plainly: minting on-device means the API
/// secret lives on the device (Keystore-backed secure storage). For
/// Richard's private, personal build that is his documented choice;
/// a shipped product must mint tokens on a server instead. This is
/// also why Crew Link stays behind its flag: enabling it is a
/// deliberate act, not a default.
String mintLiveKitToken({
  required String apiKey,
  required String apiSecret,
  required String identity,
  required String room,
  Duration ttl = const Duration(hours: 6),
}) {
  String b64url(List<int> bytes) => base64Url.encode(bytes).replaceAll('=', '');
  final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
  final header =
      b64url(utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})));
  final payload = b64url(utf8.encode(jsonEncode({
    'iss': apiKey,
    'sub': identity,
    'name': identity,
    'nbf': now,
    'exp': now + ttl.inSeconds,
    'video': {
      'roomJoin': true,
      'room': room,
      'canPublish': true,
      'canSubscribe': true,
      'canPublishData': true,
    },
  })));
  final signingInput = '$header.$payload';
  final signature =
      Hmac(sha256, utf8.encode(apiSecret)).convert(utf8.encode(signingInput));
  return '$signingInput.${b64url(signature.bytes)}';
}

/// Crew Link voice rooms over the user's own LiveKit project.
///
/// Gated in [connect]: the Crew Link flag (Settings) must be on,
/// the project URL must be set, and a token must be obtainable —
/// from the configured server token endpoint when one is set, else
/// from the on-device API key/secret pair in secure storage.
/// Missing any one throws a StateError naming exactly what is
/// missing — joining never silently degrades to something else,
/// and a failed server-token request never falls back to on-device
/// minting.
///
/// Room usage mirrors the pattern already proven in this codebase
/// (avatar_call_view.dart): Room(roomOptions: ...) + connect().
class LiveKitService {
  LiveKitService({LiveKitTokenFetcher? tokenFetcher})
      : _tokenFetcher = tokenFetcher;

  final LiveKitTokenFetcher? _tokenFetcher;
  Room? _room;
  EventsListener<RoomEvent>? _listener;

  bool get isConnected => _room != null;

  /// The token source the current Settings select: a configured
  /// server endpoint takes precedence; otherwise on-device minting
  /// (SEC-01 private-build risk).
  LiveKitTokenSource resolveTokenSource() =>
      AppSettings.instance.liveKitTokenEndpoint.trim().isNotEmpty
          ? LiveKitTokenSource.server
          : LiveKitTokenSource.onDevice;

  /// Obtain an access token from the selected source. The server
  /// path never reads the on-device secret; the on-device path
  /// fails explicitly when the key/secret pair is absent.
  Future<String> obtainToken({
    required String roomName,
    required String identity,
  }) async {
    final endpointRaw = AppSettings.instance.liveKitTokenEndpoint.trim();
    if (endpointRaw.isNotEmpty) {
      final endpoint = Uri.tryParse(endpointRaw);
      if (endpoint == null || !endpoint.hasScheme) {
        throw StateError(
            'LiveKit token endpoint is not a valid URL: $endpointRaw');
      }
      final fetcher = _tokenFetcher ??
          ((
                  {required Uri endpoint,
                  required String roomName,
                  required String identity}) =>
              fetchServerMintedLiveKitToken(
                endpoint: endpoint,
                roomName: roomName,
                identity: identity,
              ));
      return fetcher(
          endpoint: endpoint, roomName: roomName, identity: identity);
    }
    final apiKey = await SecureKeys.liveKitApiKey;
    final apiSecret = await SecureKeys.liveKitApiSecret;
    if (apiKey == null ||
        apiKey.isEmpty ||
        apiSecret == null ||
        apiSecret.isEmpty) {
      throw StateError(
          'LiveKit API key/secret not in secure storage (Settings)');
    }
    return mintLiveKitToken(
      apiKey: apiKey,
      apiSecret: apiSecret,
      identity: identity,
      room: roomName,
    );
  }

  /// Remote participants currently in the room (real SDK state).
  Map<String, RemoteParticipant> get remoteParticipants =>
      _room?.remoteParticipants ?? const {};

  Future<void> connect({
    required String roomName,
    required String identity,
    void Function(RoomEvent event)? onEvent,
  }) async {
    final s = AppSettings.instance;
    if (!s.crewLinkEnabled) {
      throw StateError(
          'Crew Link is off - enable it in Settings to join a room');
    }
    if (s.liveKitUrl.trim().isEmpty) {
      throw StateError('no LiveKit project URL set in Settings');
    }
    await disconnect();
    final token = await obtainToken(roomName: roomName, identity: identity);
    final room = Room(
      roomOptions: const RoomOptions(
        adaptiveStream: true,
        dynacast: true,
      ),
    );
    _room = room;
    if (onEvent != null) {
      _listener = room.createListener();
      _listener!.on<RoomEvent>((e) => onEvent(e));
    }
    await room.connect(s.liveKitUrl.trim(), token);
    // Voice-first: publish the microphone. Camera stays off unless
    // a caller explicitly enables it — Crew Link is a voice link.
    await room.localParticipant?.setMicrophoneEnabled(true);
  }

  Future<void> disconnect() async {
    await _listener?.dispose();
    _listener = null;
    final room = _room;
    _room = null;
    if (room != null) {
      await room.disconnect();
      await room.dispose();
    }
  }
}
