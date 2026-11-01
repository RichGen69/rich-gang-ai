import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// NVIDIA API key storage. VERIFIED package: flutter_secure_storage
/// (Keystore-backed on Android). Never SharedPreferences, never source.
class SecureKeys {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
  );
  static const _keyName = 'nvidia_api_key';

  static Future<String?> get nvidiaKey async => _storage.read(key: _keyName);

  static Future<void> setNvidiaKey(String key) async {
    final k = key.trim();
    if (!k.startsWith('nvapi-')) {
      throw ArgumentError('NVIDIA keys start with "nvapi-"');
    }
    await _storage.write(key: _keyName, value: k);
  }

  static Future<void> clearNvidiaKey() async => _storage.delete(key: _keyName);

  // ElevenLabs voice key (character voices, see voice_engine.dart).
  // No prefix is enforced: the rule for NVIDIA keys is documented;
  // inventing one for ElevenLabs would be a guessed validation.
  static const _elevenKeyName = 'elevenlabs_api_key';

  static Future<String?> get elevenLabsKey async =>
      _storage.read(key: _elevenKeyName);

  static Future<void> setElevenLabsKey(String key) async {
    final k = key.trim();
    if (k.isEmpty) throw ArgumentError('ElevenLabs key is empty');
    await _storage.write(key: _elevenKeyName, value: k);
  }

  static Future<void> clearElevenLabsKey() async =>
      _storage.delete(key: _elevenKeyName);

  // HeyGen streaming avatar key (video calls, see heygen.dart).
  static const _heygenKeyName = 'heygen_api_key';

  static Future<String?> get heyGenKey async =>
      _storage.read(key: _heygenKeyName);

  static Future<void> setHeyGenKey(String key) async {
    final k = key.trim();
    if (k.isEmpty) throw ArgumentError('HeyGen key is empty');
    await _storage.write(key: _heygenKeyName, value: k);
  }

  static Future<void> clearHeyGenKey() async =>
      _storage.delete(key: _heygenKeyName);

  // --- Cloud API keys added 2026-10-21 (Richard's request) -----------
  // One generic slot pattern per service. No prefix validation is
  // invented for any of them: a wrong key fails at the provider with
  // the API's own error, surfaced verbatim.

  static Future<String?> _read(String name) => _storage.read(key: name);

  static Future<void> _write(String name, String key, String label) async {
    final k = key.trim();
    if (k.isEmpty) throw ArgumentError('$label key is empty');
    await _storage.write(key: name, value: k);
  }

  static const _openAiKeyName = 'openai_api_key';
  static Future<String?> get openAiKey async => _read(_openAiKeyName);
  static Future<void> setOpenAiKey(String key) =>
      _write(_openAiKeyName, key, 'OpenAI');
  static Future<void> clearOpenAiKey() async =>
      _storage.delete(key: _openAiKeyName);

  static const _geminiKeyName = 'gemini_api_key';
  static Future<String?> get geminiKey async => _read(_geminiKeyName);
  static Future<void> setGeminiKey(String key) =>
      _write(_geminiKeyName, key, 'Gemini');
  static Future<void> clearGeminiKey() async =>
      _storage.delete(key: _geminiKeyName);

  static const _deepgramKeyName = 'deepgram_api_key';
  static Future<String?> get deepgramKey async => _read(_deepgramKeyName);
  static Future<void> setDeepgramKey(String key) =>
      _write(_deepgramKeyName, key, 'Deepgram');
  static Future<void> clearDeepgramKey() async =>
      _storage.delete(key: _deepgramKeyName);

  // LiveAvatar key (liveavatar.dart). LiveAvatar is HeyGen's
  // production realtime-avatar platform — a SEPARATE platform,
  // plan and key from api.heygen.com, so it gets its own slot;
  // reusing the HeyGen key here would fail auth, not "just work".
  static const _liveAvatarKeyName = 'liveavatar_api_key';
  static Future<String?> get liveAvatarKey async => _read(_liveAvatarKeyName);
  static Future<void> setLiveAvatarKey(String key) =>
      _write(_liveAvatarKeyName, key, 'LiveAvatar');
  static Future<void> clearLiveAvatarKey() async =>
      _storage.delete(key: _liveAvatarKeyName);

  // LiveKit needs an API key + API secret pair (the secret signs the
  // access token) plus the project URL, which is not a secret and
  // lives in AppSettings.
  static const _liveKitKeyName = 'livekit_api_key';
  static const _liveKitSecretName = 'livekit_api_secret';
  static Future<String?> get liveKitApiKey async => _read(_liveKitKeyName);
  static Future<void> setLiveKitApiKey(String key) =>
      _write(_liveKitKeyName, key, 'LiveKit API');
  static Future<String?> get liveKitApiSecret async =>
      _read(_liveKitSecretName);
  static Future<void> setLiveKitApiSecret(String key) =>
      _write(_liveKitSecretName, key, 'LiveKit secret');
  static Future<void> clearLiveKit() async {
    await _storage.delete(key: _liveKitKeyName);
    await _storage.delete(key: _liveKitSecretName);
  }

  /// Remove EVERY provider credential this app stores. Used by the
  /// Settings "Remove all API keys" action (SEC-02/SEC-07): after
  /// this completes, every provider must fail explicitly for a
  /// missing key rather than fall back to a remembered one.
  static Future<void> clearAll() async {
    await clearNvidiaKey();
    await clearElevenLabsKey();
    await clearHeyGenKey();
    await clearOpenAiKey();
    await clearGeminiKey();
    await clearDeepgramKey();
    await clearLiveAvatarKey();
    await clearLiveKit();
  }
}
