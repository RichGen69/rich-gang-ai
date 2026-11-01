import 'dart:convert';
import 'package:http/http.dart' as http;
import 'character.dart';
import 'secure_keys.dart';

/// LiveAvatar — HeyGen's production realtime-avatar platform
/// (liveavatar.com), the official successor to the legacy HeyGen
/// Interactive Avatar streaming API in heygen.dart.
///
/// WHY THIS EXISTS (verified 2026-10-21 from this workspace):
/// HeyGen's help center states LiveAvatar is "the official
/// production version" of Interactive Avatar, hosted on a separate
/// platform with its own plans/credits — and avatars are NOT
/// cross-compatible between the two. Meanwhile the legacy
/// POST api.heygen.com/v1/streaming.create_token answers 404 to an
/// invalid key while every LiveAvatar route probed answers a
/// proper 401 with a structured error envelope. The legacy client
/// (heygen.dart) stays available until HeyGen's stated v1/v2
/// sunset (2026-10-31); this is the path that works going forward.
///
/// VERIFIED API SHAPE (official OpenAPI at docs.liveavatar.com,
/// checked 2026-10-21; base https://api.liveavatar.com, auth
/// header `X-API-KEY`):
///   POST /v1/contexts {name<=64, prompt, opening_text}
///        -> {code, data:{id, ...}, message}
///   POST /v1/sessions/token (X-API-KEY)
///        FULL: {mode:"FULL", avatar_id, avatar_persona:
///               {context_id, voice_id?, language}}
///        -> {code, data:{session_id, session_token}, message}
///   POST /v1/sessions/start (Bearer <session_token>) -> 201
///        -> {code, data:{session_id, livekit_url,
///               livekit_client_token, livekit_agent_token,
///               max_session_duration, ws_url}, message}
///   POST /v1/sessions/stop (X-API-KEY or Bearer)
///        {session_id, reason:"USER_CLOSED"}
///   GET  /v1/sessions/{session_id}/transcript (X-API-KEY,
///        optional start_timestamp / end_timestamp query)
///        -> {code, data:{session_active, next_timestamp,
///               transcript_data:[{role:"user"|"avatar",
///               transcript, absolute_timestamp,
///               relative_timestamp}]}, message}
///        Shape verified 2026-10-30 from LiveAvatar's own
///        OpenAPI (docs.liveavatar.com, Get Session Transcript).
///        The OpenAPI does NOT state the units of
///        absolute_timestamp / relative_timestamp, so the
///        parser below treats epoch-ms values (>= 1e12) as
///        milliseconds, epoch-seconds values as seconds, and
///        otherwise falls back to the call's start time plus
///        the relative value — order is preserved, and a
///        fallback timestamp is never presented as a precise
///        API timestamp. Pagination via next_timestamp ->
///        start_timestamp is the same field pairing, and is
///        NOT live-verified (no LiveAvatar key exists in this
///        environment to probe with); a fetch that returns
///        no usable page simply returns the lines it got.
///
/// MODE CHOICE: FULL. In FULL mode LiveAvatar runs the
/// conversation pipeline (STT -> LLM -> TTS) driven by the
/// character's Context, which this app creates from the
/// character's own definition (see [contextPromptFor]). That is
/// disclosed in the call UI: a LiveAvatar call does NOT route
/// through the in-app brain/memory — the character's persona is
/// carried by its Context instead. LITE mode was not chosen: it
/// takes raw PCM audio over a WebSocket, and this app has no
/// verified PCM-24kHz audio path to feed it.
class LiveAvatarException implements Exception {
  LiveAvatarException(this.message);
  final String message;
  @override
  String toString() => 'LiveAvatarException: $message';
}

/// A minted (not yet started) LiveAvatar session token.
class LiveAvatarToken {
  const LiveAvatarToken({required this.sessionId, required this.sessionToken});
  final String sessionId;
  final String sessionToken;

  static LiveAvatarToken? tryParse(String body) {
    final data = LiveAvatarService.envelopeData(body);
    if (data == null) return null;
    final sid = data['session_id'];
    final tok = data['session_token'];
    if (sid is! String || tok is! String || tok.isEmpty) return null;
    return LiveAvatarToken(sessionId: sid, sessionToken: tok);
  }
}

/// A started LiveAvatar session: join its LiveKit room with
/// [liveKitClientToken] to see and hear the avatar.
class LiveAvatarSessionData {
  const LiveAvatarSessionData({
    required this.sessionId,
    required this.liveKitUrl,
    required this.liveKitClientToken,
    this.wsUrl,
  });
  final String sessionId;
  final String liveKitUrl;
  final String liveKitClientToken;
  final String? wsUrl;

  static LiveAvatarSessionData? tryParse(String body) {
    final data = LiveAvatarService.envelopeData(body);
    if (data == null) return null;
    final sid = data['session_id'];
    final url = data['livekit_url'];
    final tok = data['livekit_client_token'];
    if (sid is! String || url is! String || tok is! String) return null;
    final ws = data['ws_url'];
    return LiveAvatarSessionData(
      sessionId: sid,
      liveKitUrl: url,
      liveKitClientToken: tok,
      wsUrl: ws is String ? ws : null,
    );
  }
}

/// One line of a LiveAvatar session transcript, as returned by
/// GET /v1/sessions/{session_id}/transcript. [role] is exactly
/// "user" or "avatar" from the API — the call view maps those to
/// "Richard" and the character's display name when it stores
/// them in CallHistory, so this layer invents no speaker names.
class LiveAvatarTranscriptLine {
  const LiveAvatarTranscriptLine({
    required this.role,
    required this.text,
    required this.at,
  });

  final String role;
  final String text;
  final DateTime at;

  static LiveAvatarTranscriptLine? tryParse(
    dynamic raw, {
    DateTime? sessionStartedAt,
  }) {
    if (raw is! Map<String, dynamic>) return null;
    final role = raw['role'];
    final text = raw['transcript'];
    if (role is! String || (role != 'user' && role != 'avatar')) {
      return null;
    }
    if (text is! String || text.isEmpty) return null;
    final absolute = raw['absolute_timestamp'];
    final relative = raw['relative_timestamp'];
    DateTime at;
    if (absolute is int && absolute >= 1000000000000) {
      at = DateTime.fromMillisecondsSinceEpoch(absolute, isUtc: true);
    } else if (absolute is int && absolute >= 1000000000) {
      at = DateTime.fromMillisecondsSinceEpoch(absolute * 1000,
          isUtc: true);
    } else if (relative is int && sessionStartedAt != null) {
      // Relative value, units unstated: seconds for plausible
      // in-call offsets, milliseconds above that range.
      at = relative < 10000000
          ? sessionStartedAt.add(Duration(seconds: relative))
          : sessionStartedAt.add(Duration(milliseconds: relative));
    } else {
      // No usable timestamp from the API: keep the line (its
      // text and speaker are real) and stamp it at the call
      // start, or now if even that is unknown. Order, not this
      // fallback stamp, is what the history guarantees.
      at = sessionStartedAt ?? DateTime.now();
    }
    return LiveAvatarTranscriptLine(role: role, text: text, at: at);
  }
}

class LiveAvatarService {
  LiveAvatarService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  static const baseUrl = 'https://api.liveavatar.com/v1';

  /// The {code, data, message} envelope every LiveAvatar response
  /// uses. Returns the data map, or null when the body isn't that
  /// envelope or data is null (an error envelope).
  static Map<String, dynamic>? envelopeData(String body) {
    try {
      final doc = jsonDecode(body) as Map<String, dynamic>;
      final data = doc['data'];
      return data is Map<String, dynamic> ? data : null;
    } catch (_) {
      return null;
    }
  }

  /// The envelope's human-readable message, when present.
  static String? envelopeMessage(String body) {
    try {
      final doc = jsonDecode(body) as Map<String, dynamic>;
      final m = doc['message'];
      return m is String ? m : null;
    } catch (_) {
      return null;
    }
  }

  Future<String> _requireKey() async {
    final key = await SecureKeys.liveAvatarKey;
    if (key == null || key.isEmpty) {
      throw LiveAvatarException(
          'no LiveAvatar API key in secure storage (Settings)');
    }
    return key;
  }

  Map<String, dynamic> _okData(http.Response r, String what) {
    if (r.statusCode < 200 || r.statusCode >= 300) {
      final msg = envelopeMessage(r.body);
      throw LiveAvatarException(
          '$what HTTP ${r.statusCode}${msg == null ? '' : ': $msg'}');
    }
    final data = envelopeData(r.body);
    if (data == null) {
      throw LiveAvatarException('$what response had no data envelope');
    }
    return data;
  }

  /// Create a Context (the character's persona for FULL mode)
  /// server-side and return its id. The app stores the id per
  /// character and reuses it; it never re-creates blindly.
  Future<String> createContext({
    required String name,
    required String prompt,
    required String openingText,
  }) async {
    final key = await _requireKey();
    final trimmedName = name.length > 64 ? name.substring(0, 64) : name;
    final r = await _client
        .post(
          Uri.parse('$baseUrl/contexts'),
          headers: {'X-API-KEY': key, 'Content-Type': 'application/json'},
          body: jsonEncode({
            'name': trimmedName,
            'prompt': prompt,
            'opening_text': openingText,
          }),
        )
        .timeout(const Duration(seconds: 30));
    final data = _okData(r, 'create context');
    final id = data['id'];
    if (id is! String || id.isEmpty) {
      throw LiveAvatarException('create context returned no id');
    }
    return id;
  }

  /// Mint a FULL-mode session token for [avatarId] + [contextId].
  Future<LiveAvatarToken> createSessionToken({
    required String avatarId,
    required String contextId,
    String? voiceId,
    String language = 'en',
  }) async {
    final key = await _requireKey();
    if (avatarId.trim().isEmpty) {
      throw LiveAvatarException(
          'no LiveAvatar avatar configured for this character');
    }
    final r = await _client
        .post(
          Uri.parse('$baseUrl/sessions/token'),
          headers: {'X-API-KEY': key, 'Content-Type': 'application/json'},
          body: jsonEncode({
            'mode': 'FULL',
            'avatar_id': avatarId.trim(),
            'avatar_persona': {
              'context_id': contextId,
              if (voiceId != null && voiceId.trim().isNotEmpty)
                'voice_id': voiceId.trim(),
              'language': language,
            },
          }),
        )
        .timeout(const Duration(seconds: 30));
    _okData(r, 'create session token');
    final token = LiveAvatarToken.tryParse(r.body);
    if (token == null) {
      throw LiveAvatarException('session token response unparseable');
    }
    return token;
  }

  /// Start the session a token was minted for (Bearer auth).
  Future<LiveAvatarSessionData> startSession(String sessionToken) async {
    final r = await _client
        .post(
          Uri.parse('$baseUrl/sessions/start'),
          headers: {
            'Authorization': 'Bearer $sessionToken',
            'Content-Type': 'application/json',
          },
        )
        .timeout(const Duration(seconds: 30));
    _okData(r, 'start session');
    final session = LiveAvatarSessionData.tryParse(r.body);
    if (session == null) {
      throw LiveAvatarException('start session response unparseable');
    }
    return session;
  }

  /// Stop a session. Best-effort like the legacy client: a failed
  /// stop is not worth masking the call's own outcome (sessions
  /// also end on their own duration/idle limits).
  Future<void> stopSession(String sessionId) async {
    try {
      final key = await SecureKeys.liveAvatarKey;
      if (key == null || key.isEmpty) return;
      await _client
          .post(
            Uri.parse('$baseUrl/sessions/stop'),
            headers: {'X-API-KEY': key, 'Content-Type': 'application/json'},
            body: jsonEncode({
              'session_id': sessionId,
              'reason': 'USER_CLOSED',
            }),
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      // See class docs.
    }
  }

  /// Fetch a finished (or in-progress) FULL-mode session's
  /// transcript, once, at call end. Returns only lines the API
  /// actually returned, in API order; an unusable line is
  /// dropped, never repaired with invented text. Throws
  /// [LiveAvatarException] on a missing key, a non-2xx
  /// response, or a response with no transcript_data — the
  /// caller (the call view) treats that as "metadata only",
  /// not as a reason to invent lines. Pagination follows
  /// next_timestamp -> start_timestamp, capped at 20 pages
  /// so a looping cursor cannot hang the call-end path.
  Future<List<LiveAvatarTranscriptLine>> fetchTranscript(
    String sessionId, {
    DateTime? sessionStartedAt,
  }) async {
    final key = await _requireKey();
    final lines = <LiveAvatarTranscriptLine>[];
    int? startTimestamp;
    for (var page = 0; page < 20; page++) {
      final uri = Uri.parse('$baseUrl/sessions/$sessionId/transcript')
          .replace(
        queryParameters: startTimestamp == null
            ? null
            : {'start_timestamp': '$startTimestamp'},
      );
      final r = await _client
          .get(uri, headers: {'X-API-KEY': key})
          .timeout(const Duration(seconds: 30));
      final data = _okData(r, 'fetch transcript');
      final rawLines = data['transcript_data'];
      if (rawLines is! List) {
        throw LiveAvatarException(
            'transcript response had no transcript_data');
      }
      for (final raw in rawLines) {
        final line = LiveAvatarTranscriptLine.tryParse(
          raw,
          sessionStartedAt: sessionStartedAt,
        );
        if (line != null) lines.add(line);
      }
      final next = data['next_timestamp'];
      if (next is! int || next == startTimestamp) break;
      startTimestamp = next;
    }
    return lines;
  }

  /// The FULL-mode Context prompt for a character, composed ONLY
  /// from the character's own definition fields — the same source
  /// the in-app system prompt uses, so the avatar on a call is the
  /// same person as the agent in chat.
  static String contextPromptFor(CharacterDef def) {
    return [
      'You are ${def.displayName}, ${def.title}, a character in '
          'Rich Gang AI, created by Richard Perry Lambeth Jr. You '
          'are speaking live with Richard in a video call.',
      def.core,
      'Personality: ${def.personality}',
      'Speech style: ${def.speechStyle}',
      if (def.interests.isNotEmpty)
        'Interests: ${def.interests.join(', ')}.',
      'Stay in character. Be natural and conversational — this is '
          'a spoken call, so keep replies concise and human.',
    ].join('\n');
  }

  /// The line the avatar opens the call with (Context opening_text).
  static String openingTextFor(CharacterDef def) =>
      '${def.displayName} here — ${def.title}. Good to see you, '
      'Richard. What are we getting into?';
}

/// Per-character LiveAvatar configuration keys (SharedPreferences;
/// plain config, not secrets). Avatar/voice ids are LiveAvatar
/// platform ids (UUIDs from the LiveAvatar dashboard) — HeyGen
/// avatar ids do NOT work here; the platforms are separate.
class LiveAvatarConfig {
  static String avatarKeyFor(String characterId) =>
      'liveavatar_avatar_$characterId';
  static String voiceKeyFor(String characterId) =>
      'liveavatar_voice_$characterId';
  static String contextKeyFor(String characterId) =>
      'liveavatar_context_$characterId';
}
