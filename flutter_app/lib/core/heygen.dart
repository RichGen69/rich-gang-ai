import 'dart:convert';
import 'package:http/http.dart' as http;
import 'secure_keys.dart';

/// HeyGen Interactive Avatar — voice + video calling with the
/// character agents.
///
/// SUCCESSOR: HeyGen's production realtime platform is now
/// LiveAvatar (separate platform/plan/key) — see liveavatar.dart,
/// which the call screen defaults to. This legacy client remains
/// until HeyGen's stated v1/v2 sunset (2026-10-31); its token
/// endpoint already answers 404 in pre-flight probes.
///
/// VERIFIED API SHAPE (HeyGen official StreamingAvatar SDK docs,
/// checked 2026-10-21):
///   POST https://api.heygen.com/v1/streaming.create_token
///        header x-api-key -> {data:{token}}
///   POST /v1/streaming.new     (Bearer token)
///        body {quality, avatar_name, voice:{voice_id}}
///        -> {data:{session_id, access_token, url, is_paid}}
///        `url` is the LiveKit room URL; `access_token` joins it.
///   POST /v1/streaming.start   (Bearer token) {session_id}
///   POST /v1/streaming.task    (Bearer token)
///        {session_id, text, task_type:"repeat"} — the avatar
///        speaks the text (repeat = say exactly this; our agents
///        generate their own lines, so repeat is the right mode —
///        the character's words, the avatar's face and voice).
///   POST /v1/streaming.stop    (Bearer token) {session_id}
///
/// LIVE PROBE (2026-10-21, from this workspace): POST
/// streaming.create_token with an invalid key returned HTTP 404
/// (not the 401 an auth rejection would suggest), and HeyGen's own
/// developer docs now describe v1/v2 as legacy with v3 live and a
/// v1/v2 sunset of 2026-10-31. So: the request shapes above follow
/// the official v1 SDK, the token parser accepts BOTH documented
/// token field shapes (data.token and data.access_token) — and the
/// endpoint must be confirmed against Richard's real HeyGen key on
/// first use. If HeyGen answers 404 in the app, that is this known
/// open check surfacing, not an app bug.
///
/// WHAT'S WIRED HERE: the full session lifecycle + speak tasks from
/// Dart. The avatar id per character is configuration, NOT code:
/// Richard creates/selects Interactive Avatars in HeyGen's lab and
/// pastes each id in Settings (stored per character, see
/// [HeyGenAvatars]). Public avatar ids are account-specific
/// catalogue values — inventing them here would be fabrication.
///
/// VIDEO RENDERING: the stream is WebRTC via LiveKit. The call
/// view (avatar_call_view.dart) joins the room returned here with
/// livekit_client (already a project dependency) and renders the
/// avatar's video track. Compile-verified; NOT device-verified.
class HeyGenSession {
  const HeyGenSession({
    required this.sessionId,
    required this.accessToken,
    required this.liveKitUrl,
  });
  final String sessionId;
  final String accessToken;
  final String liveKitUrl;

  static HeyGenSession? tryParse(String body) {
    try {
      final doc = jsonDecode(body) as Map<String, dynamic>;
      final data = doc['data'];
      if (data is! Map<String, dynamic>) return null;
      final sid = data['session_id'];
      final tok = data['access_token'];
      final url = data['url'];
      if (sid is! String || tok is! String || url is! String) {
        return null;
      }
      return HeyGenSession(
          sessionId: sid, accessToken: tok, liveKitUrl: url);
    } catch (_) {
      return null;
    }
  }
}

class HeyGenUnavailable implements Exception {
  HeyGenUnavailable(this.message);
  final String message;
  @override
  String toString() => 'HeyGenUnavailable: $message';
}

class HeyGenService {
  HeyGenService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  static const _base = 'https://api.heygen.com/v1';
  String? _token;

  Future<String> _sessionToken(String apiKey) async {
    if (_token != null) return _token!;
    final r = await _client.post(
      Uri.parse('$_base/streaming.create_token'),
      headers: {'x-api-key': apiKey},
    ).timeout(const Duration(seconds: 20));
    if (r.statusCode != 200) {
      throw HeyGenUnavailable(
          'token request HTTP ${r.statusCode}'
          '${r.statusCode == 404 ? ' — the v1 token endpoint did not '
              'answer in pre-flight checks either; HeyGen may have '
              'moved it to v3. Verify in your HeyGen developer '
              'console before debugging the app.' : ''}');
    }
    final doc = jsonDecode(r.body) as Map<String, dynamic>;
    final data = doc['data'] as Map<String, dynamic>?;
    // Both documented shapes: {data:{token}} and
    // {data:{access_token}} (SDK token-extraction notes).
    final token = data?['token'] ?? data?['access_token'];
    if (token is! String || token.isEmpty) {
      throw HeyGenUnavailable('token response had no token');
    }
    return _token = token;
  }

  /// Create + start a session for [avatarName] (the HeyGen
  /// Interactive Avatar id configured for the character).
  Future<HeyGenSession> startSession({
    required String avatarName,
    String? voiceId,
    String quality = 'high',
  }) async {
    final key = await SecureKeys.heyGenKey;
    if (key == null || key.isEmpty) {
      throw HeyGenUnavailable(
          'no HeyGen API key in secure storage (Settings)');
    }
    if (avatarName.trim().isEmpty) {
      throw HeyGenUnavailable(
          'no HeyGen avatar configured for this character (Settings)');
    }
    final token = await _sessionToken(key);
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
    final created = await _client
        .post(
          Uri.parse('$_base/streaming.new'),
          headers: headers,
          body: jsonEncode({
            'quality': quality,
            'avatar_name': avatarName.trim(),
            if (voiceId != null) 'voice': {'voice_id': voiceId},
          }),
        )
        .timeout(const Duration(seconds: 30));
    if (created.statusCode != 200) {
      throw HeyGenUnavailable(
          'streaming.new HTTP ${created.statusCode}: ${created.body}');
    }
    final session = HeyGenSession.tryParse(created.body);
    if (session == null) {
      throw HeyGenUnavailable('streaming.new response unparseable');
    }
    final started = await _client
        .post(
          Uri.parse('$_base/streaming.start'),
          headers: headers,
          body: jsonEncode({'session_id': session.sessionId}),
        )
        .timeout(const Duration(seconds: 30));
    if (started.statusCode != 200) {
      throw HeyGenUnavailable(
          'streaming.start HTTP ${started.statusCode}');
    }
    return session;
  }

  /// Make the avatar say [text] — the character agent's own words.
  Future<void> speak(HeyGenSession session, String text) async {
    final token = _token;
    if (token == null) {
      throw HeyGenUnavailable('no active session token');
    }
    final r = await _client
        .post(
          Uri.parse('$_base/streaming.task'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'session_id': session.sessionId,
            'text': text,
            'task_type': 'repeat',
          }),
        )
        .timeout(const Duration(seconds: 30));
    if (r.statusCode != 200) {
      throw HeyGenUnavailable('streaming.task HTTP ${r.statusCode}');
    }
  }

  Future<void> stop(HeyGenSession session) async {
    final token = _token;
    if (token == null) return;
    try {
      await _client
          .post(
            Uri.parse('$_base/streaming.stop'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'session_id': session.sessionId}),
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      // Session also expires server-side; a failed stop is not
      // worth surfacing over the call's own result.
    }
  }
}

/// Per-character HeyGen avatar ids, persisted in SharedPreferences
/// by the Settings UI (plain config, not a secret). Empty = video
/// calling not configured for that character yet.
class HeyGenAvatars {
  static String prefsKeyFor(String characterId) => 'heygen_avatar_$characterId';
}
