import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'secure_keys.dart';

/// Deepgram speech APIs. VERIFIED against Deepgram's docs:
/// - STT: POST https://api.deepgram.com/v1/listen with header
///   `Authorization: Token <key>`; either a JSON {"url": ...} body for
///   a hosted file or raw audio bytes with the matching Content-Type.
///   Transcript lives at results.channels[0].alternatives[0].transcript.
/// - TTS (Aura): POST https://api.deepgram.com/v1/speak?model=... with
///   a JSON {"text": ...} body; the response body is the audio.
///
/// No microphone capture is wired here — there is no verified audio
/// recorder in this build yet, and pretending otherwise would fake
/// the input half of the pipeline. Callers supply audio (a URL or
/// bytes they obtained) and get real transcripts/audio back.
class DeepgramClient {
  static const _listenBase = 'https://api.deepgram.com/v1/listen';
  static const _speakBase = 'https://api.deepgram.com/v1/speak';

  /// Default STT model (Deepgram's current general model per docs).
  static const sttModel = 'nova-3';

  /// Default Aura voice model (documented example voice).
  static const ttsModel = 'aura-2-thalia-en';

  Future<String> _key() async {
    final key = await SecureKeys.deepgramKey;
    if (key == null || key.isEmpty) {
      throw StateError('no Deepgram API key configured');
    }
    return key;
  }

  String _transcriptFrom(http.Response r) {
    if (r.statusCode != 200) {
      throw StateError('Deepgram HTTP ${r.statusCode}: ${r.body}');
    }
    final decoded = jsonDecode(r.body) as Map<String, dynamic>;
    final results = decoded['results'] as Map<String, dynamic>?;
    final channels = results?['channels'] as List<dynamic>?;
    // .first on an EMPTY (non-null) list throws — guard both hops.
    final channel0 = (channels != null && channels.isNotEmpty)
        ? channels.first as Map<String, dynamic>?
        : null;
    final alternatives = channel0?['alternatives'] as List<dynamic>?;
    final alt0 = (alternatives != null && alternatives.isNotEmpty)
        ? alternatives.first as Map<String, dynamic>?
        : null;
    final transcript = alt0?['transcript'];
    if (transcript is! String) {
      throw StateError('Deepgram response had no transcript: ${r.body}');
    }
    return transcript;
  }

  /// Transcribe audio hosted at [url] (Deepgram fetches it).
  Future<String> transcribeUrl(String url) async {
    final key = await _key();
    final r = await http
        .post(
          Uri.parse('$_listenBase?model=$sttModel&smart_format=true'),
          headers: {
            'Authorization': 'Token $key',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'url': url}),
        )
        .timeout(const Duration(seconds: 120));
    return _transcriptFrom(r);
  }

  /// Transcribe raw audio [bytes] with their real [contentType]
  /// (e.g. 'audio/wav', 'audio/mpeg').
  Future<String> transcribeBytes(Uint8List bytes, String contentType) async {
    final key = await _key();
    final r = await http
        .post(
          Uri.parse('$_listenBase?model=$sttModel&smart_format=true'),
          headers: {
            'Authorization': 'Token $key',
            'Content-Type': contentType,
          },
          body: bytes,
        )
        .timeout(const Duration(seconds: 120));
    return _transcriptFrom(r);
  }

  /// Synthesize speech with Aura; returns the audio bytes exactly as
  /// the API produced them (playback is the caller's device concern).
  Future<Uint8List> speak(String text, {String model = ttsModel}) async {
    final key = await _key();
    final r = await http
        .post(
          Uri.parse('$_speakBase?model=$model'),
          headers: {
            'Authorization': 'Token $key',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'text': text}),
        )
        .timeout(const Duration(seconds: 60));
    if (r.statusCode != 200) {
      throw StateError(
          'Deepgram speak HTTP ${r.statusCode}: ${r.body}');
    }
    return r.bodyBytes;
  }
}
