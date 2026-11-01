import 'dart:convert';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'affect_engine.dart';
import 'character.dart';
import 'secure_keys.dart';

/// How an utterance should SOUND, derived from the character's
/// casting + its REAL affect state in this moment.
///
/// The mapping rules (prosody director, design constants):
/// - arousal raises rate and (for ElevenLabs) exaggerates style and
///   lowers stability, so an excited/furious agent does not read
///   flat; low arousal does the opposite.
/// - pleasure below -0.4 lowers pitch slightly (heavier delivery);
///   pleasure above 0.4 lifts it.
/// Everything is clamped to the providers' real parameter ranges.
class Prosody {
  const Prosody({
    required this.rate,
    required this.pitch,
    required this.stability,
    required this.style,
  });
  final double rate; // flutter_tts: 0..1 around casting rate
  final double pitch; // flutter_tts: 0.5..2.0
  final double stability; // ElevenLabs: 0..1
  final double style; // ElevenLabs: 0..1

  static Prosody from(VoiceCasting cast, Pad pad) {
    final rate = (cast.systemRate + pad.arousal * 0.12).clamp(0.2, 0.9);
    var pitch = cast.systemPitch;
    if (pad.pleasure < -0.4) pitch -= 0.08;
    if (pad.pleasure > 0.4) pitch += 0.06;
    final stability =
        (cast.stability - pad.arousal * 0.18).clamp(0.05, 1.0);
    final style =
        (cast.style + (pad.arousal > 0 ? pad.arousal * 0.25 : 0.0))
            .clamp(0.0, 1.0);
    return Prosody(
      rate: rate.toDouble(),
      pitch: pitch.clamp(0.5, 2.0).toDouble(),
      stability: stability.toDouble(),
      style: style.toDouble(),
    );
  }
}

enum VoicePath {
  /// ElevenLabs Multilingual v2 — the premium neural voices.
  elevenLabs,

  /// The phone's own TTS engine via flutter_tts.
  system,
}

/// Gives every agent its voice.
///
/// HONEST QUALITY NOTE (Richard's no-mock rule): no TTS system is
/// guaranteed indistinguishable from a human, and this class never
/// claims otherwise in the UI. The ElevenLabs path is currently the
/// closest widely available — natural intonation, emotion carried
/// by the [Prosody] settings — and it needs Richard's own ElevenLabs
/// key in secure storage. Without a key (or if the API fails) the
/// engine falls back to the phone's system TTS and REPORTS that it
/// did via [lastPath], so a robotic fallback is never silently
/// passed off as the premium voice. The Kokoro casting names in
/// characters.json are for the future on-device path (see
/// character.dart) — no Kokoro audio is produced by this build.
class VoiceEngine {
  VoiceEngine({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  // Lazily created: constructing the players eagerly (at session
  // construction) throws in environments without the platform
  // plugins (tests), and nothing needs them until the first
  // speak/stop. Behaviour for real use is unchanged — they are
  // created on first use, exactly when they were previously
  // already alive.
  AudioPlayer? _playerCache;
  AudioPlayer get _player => _playerCache ??= AudioPlayer();
  FlutterTts? _systemCache;
  FlutterTts get _system => _systemCache ??= FlutterTts();

  VoicePath? lastPath;

  static const _model = 'eleven_multilingual_v2';

  /// Speak [text] as [character], feeling [pad]. Returns the path
  /// actually used. Throws only if BOTH paths fail.
  Future<VoicePath> speak(
      CharacterDef character, Pad pad, String text) async {
    final clean = text.trim();
    if (clean.isEmpty) return lastPath = VoicePath.system;
    final prosody = Prosody.from(character.voice, pad);

    final key = await SecureKeys.elevenLabsKey;
    if (key != null && key.isNotEmpty) {
      try {
        final bytes = await synthesizeElevenLabs(
          key: key,
          voiceId: character.voice.elevenLabsVoiceId,
          text: clean,
          prosody: prosody,
        );
        await _player.stop();
        await _player.play(BytesSource(bytes));
        return lastPath = VoicePath.elevenLabs;
      } catch (_) {
        // Fall through to the system voice; lastPath reports it.
      }
    }
    await _speakSystem(character, prosody, clean);
    return lastPath = VoicePath.system;
  }

  /// ElevenLabs TTS REST call (POST /v1/text-to-speech/{voice_id},
  /// verified API shape, model eleven_multilingual_v2). Returns the
  /// raw MP3 bytes — separated from playback so it is testable.
  Future<Uint8List> synthesizeElevenLabs({
    required String key,
    required String voiceId,
    required String text,
    required Prosody prosody,
  }) async {
    final uri = Uri.parse(
        'https://api.elevenlabs.io/v1/text-to-speech/$voiceId');
    final r = await _client
        .post(
          uri,
          headers: {
            'xi-api-key': key,
            'Content-Type': 'application/json',
            'Accept': 'audio/mpeg',
          },
          body: jsonEncode({
            'text': text,
            'model_id': _model,
            'voice_settings': {
              'stability': prosody.stability,
              'similarity_boost': 0.75,
              'style': prosody.style,
              'use_speaker_boost': true,
            },
          }),
        )
        .timeout(const Duration(seconds: 45));
    if (r.statusCode != 200) {
      throw StateError('ElevenLabs HTTP ${r.statusCode}');
    }
    return r.bodyBytes;
  }

  Future<void> _speakSystem(
      CharacterDef character, Prosody prosody, String text) async {
    // A previous ElevenLabs clip could still be playing (e.g. the
    // key was removed mid-session) — never talk over it.
    await _player.stop();
    await _system.setLanguage('en-US');
    await _system.setSpeechRate(prosody.rate);
    await _system.setPitch(prosody.pitch);
    await _system.speak(text);
  }

  Future<void> stop() async {
    await _player.stop();
    await _system.stop();
  }
}
