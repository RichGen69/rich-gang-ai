import 'dart:convert';
import 'package:http/http.dart' as http;
import 'secure_keys.dart';
import 'settings.dart';

/// HeyGen offline avatar VIDEO GENERATION (the non-streaming API).
/// Sibling to heygen.dart, which covers Interactive Avatar streaming
/// sessions for live calls; this client queues rendered videos.
///
/// VERIFIED shape (HeyGen docs):
/// - Auth: `X-Api-Key: <key>` header.
/// - Avatars: GET https://api.heygen.com/v2/avatars
/// - Voices: GET https://api.heygen.com/v2/voices
/// - Create: POST https://api.heygen.com/v2/video/generate with
///   {"video_inputs":[{"character":{"type":"avatar","avatar_id":...},
///   "voice":{"type":"text","input_text":...,"voice_id":...}}],
///   "dimension":{"width":1280,"height":720}} -> data.video_id
/// - Status: GET https://api.heygen.com/v1/video_status.get?video_id=
///   -> data.status and, when completed, data.video_url.
///
/// Generation is asynchronous and billed by HeyGen: this client
/// creates a job only when explicitly called and never polls on its
/// own. Avatar/voice IDs come from Settings (picked from the
/// account's own library via the list calls); generation refuses
/// without them rather than guessing catalogue IDs.
class HeyGenVideoClient {
  static const _base = 'https://api.heygen.com';

  Future<String> _key() async {
    final key = await SecureKeys.heyGenKey;
    if (key == null || key.isEmpty) {
      throw StateError('no HeyGen API key configured');
    }
    return key;
  }

  Future<Map<String, dynamic>> _get(String path) async {
    final key = await _key();
    final r = await http.get(
      Uri.parse('$_base$path'),
      headers: {'X-Api-Key': key},
    ).timeout(const Duration(seconds: 30));
    if (r.statusCode != 200) {
      throw StateError('HeyGen HTTP ${r.statusCode}: ${r.body}');
    }
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  /// The account's avatar library (raw API document).
  Future<Map<String, dynamic>> listAvatars() => _get('/v2/avatars');

  /// The account's voice library (raw API document).
  Future<Map<String, dynamic>> listVoices() => _get('/v2/voices');

  /// Queue one avatar video reading [script]. Returns the video_id.
  Future<String> createVideo(String script) async {
    final s = AppSettings.instance;
    if (s.heyGenAvatarId.isEmpty || s.heyGenVoiceId.isEmpty) {
      throw StateError(
          'HeyGen avatar/voice not chosen yet - pick them from the '
          'account library and save their IDs in Settings');
    }
    final key = await _key();
    final r = await http
        .post(
          Uri.parse('$_base/v2/video/generate'),
          headers: {
            'X-Api-Key': key,
            'Content-Type': 'application/json',
          },
          body: jsonEncode(<String, dynamic>{
            'video_inputs': [
              {
                'character': {
                  'type': 'avatar',
                  'avatar_id': s.heyGenAvatarId,
                  'avatar_style': 'normal',
                },
                'voice': {
                  'type': 'text',
                  'input_text': script,
                  'voice_id': s.heyGenVoiceId,
                },
              }
            ],
            'dimension': {'width': 1280, 'height': 720},
          }),
        )
        .timeout(const Duration(seconds: 30));
    if (r.statusCode != 200) {
      throw StateError('HeyGen HTTP ${r.statusCode}: ${r.body}');
    }
    final decoded = jsonDecode(r.body) as Map<String, dynamic>;
    final data = decoded['data'] as Map<String, dynamic>?;
    final id = data?['video_id'];
    if (id is! String || id.isEmpty) {
      throw StateError('HeyGen create returned no video_id: ${r.body}');
    }
    return id;
  }

  /// One status read for [videoId]: the API's `data` object verbatim
  /// (status; video_url when completed). No polling loop here.
  Future<Map<String, dynamic>> videoStatus(String videoId) async {
    final doc = await _get('/v1/video_status.get?video_id=$videoId');
    final data = doc['data'];
    if (data is! Map<String, dynamic>) {
      throw StateError('HeyGen status had no data object: $doc');
    }
    return data;
  }
}
