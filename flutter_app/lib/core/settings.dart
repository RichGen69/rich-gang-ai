import 'package:flutter/foundation.dart';

enum TrustDial { silent, standard, theater }

/// User settings (Restraint Layer first - Tier 0).
///
/// Milestones 1-3 scope: values are held by this singleton for the session.
/// Durable persistence (except the NVIDIA key, see SecureKeys) is wired
/// with the settings UI at its milestone; nothing here pretends otherwise.
class AppSettings extends ChangeNotifier {
  AppSettings._();
  static final AppSettings instance = AppSettings._();

  TrustDial trustDial = TrustDial.standard;

  /// 60 (default) or 30 (Cinematic). Never 120.
  int frameRate = 60;

  /// On Android 127.0.0.1 is the phone itself, not the dev machine.
  String ollamaBaseUrl = 'http://127.0.0.1:11434/v1';
  String ollamaModel = 'llama3.2:3b';

  /// Verify the current model slug on build.nvidia.com before Milestone 5;
  /// hosted model IDs rotate (see docs/VERIFY.md).
  String nvidiaModel = 'meta/llama-3.3-70b-instruct';

  /// Which cloud provider the router tries first for non-local tasks:
  /// 'nvidia' (spec default), 'openai', or 'gemini'. Ollama remains
  /// the fallback for all three, and local-only tasks never leave the
  /// device regardless of this setting.
  String cloudProvider = 'nvidia';

  /// OpenAI model. Default is GPT-6 Astra (OpenAI's flagship, released
  /// 2026-09-03, available via the OpenAI API per release coverage).
  /// Hosted model IDs rotate and the exact slug must be confirmed in
  /// the OpenAI dashboard — if it is wrong, the provider surfaces the
  /// API's own error rather than hiding it.
  String openAiModel = 'gpt-6-astra';

  /// Gemini model. Default from Google's own API reference example.
  /// Confirm the current ID on Google's models page before relying on
  /// it; Gemini's lineup changes often.
  String geminiModel = 'gemini-2.5-flash';

  /// LiveKit project URL (wss://...). Not a secret — the API key and
  /// secret live in SecureKeys.
  String liveKitUrl = '';

  /// Optional server token endpoint for Crew Link (SEC-01): when
  /// set, LiveKit access tokens are fetched from this endpoint
  /// (POST {"room": ..., "identity": ...} -> {"token": ...}) and
  /// the on-device API secret is NOT used. When empty, tokens are
  /// minted on-device — a private-build risk, labelled as such in
  /// Settings. Session-only, like the project URL.
  String liveKitTokenEndpoint = '';

  /// HeyGen avatar/voice IDs, chosen from the account's own library
  /// (HeyGenClient.listAvatars / listVoices). Empty until Richard
  /// picks them; video generation refuses without them.
  String heyGenAvatarId = '';
  String heyGenVoiceId = '';

  final Map<String, bool> personaVoiceMuted = <String, bool>{};
  bool ambientEnabled = false;

  /// Crew Link (build order step 7 — last, flagged, paired-only).
  /// The flag exists so the feature can be switched on deliberately;
  /// there is NO transport behind it yet and no device is paired, so
  /// enabling it alone connects nothing and shares nothing. Pairing
  /// is a separate build step and must not be implied by this flag.
  bool crewLinkEnabled = false;

  /// 1-based count of THIS launch, loaded from durable storage in
  /// main() before runApp. 0 means the counter could not be read —
  /// the cold open then stays off under Standard rather than guessing.
  int launchCount = 0;

  DateTime? _killUntil;

  /// One tap in The Room: silences all ambient for 24 hours.
  void tripKillSwitch() {
    _killUntil = DateTime.now().add(const Duration(hours: 24));
    notifyListeners();
  }

  bool get ambientKilled =>
      _killUntil != null && DateTime.now().isBefore(_killUntil!);

  /// Quiet hours 22:00-08:00: no ambient audio, no shaders, no haptics.
  static bool get inQuietHours {
    final h = DateTime.now().hour;
    return h >= 22 || h < 8;
  }

  /// The single gate every ambient feature must pass.
  bool ambientAllowed({required bool systemDnd, required bool reducedMotion}) {
    if (trustDial == TrustDial.silent) return false;
    if (!ambientEnabled && trustDial != TrustDial.theater) return false;
    if (ambientKilled || inQuietHours) return false;
    if (systemDnd || reducedMotion) return false;
    return true;
  }

  /// Decaying cold open (build order step 1): how long the launch
  /// sequence runs on THIS launch, or Duration.zero to skip it.
  ///
  /// Schedule per the Trust Dial canon (Standard = cold open on the
  /// first 3 launches, then off):
  /// - Silent: never.
  /// - Standard: launch 1 = 2400 ms, 2 = 1600 ms, 3 = 800 ms, then off.
  /// - Theater: full 2400 ms every launch (the user opted in).
  ///
  /// Hard gates at every dial position: the kill switch, quiet hours
  /// (22:00-08:00 — the room is dim and static), and the system's
  /// reduced-motion setting. The sequence is visual only — it never
  /// plays audio or fires haptics — so DND does not gate it.
  Duration coldOpenDuration({required bool reducedMotion}) {
    if (ambientKilled || inQuietHours || reducedMotion) {
      return Duration.zero;
    }
    switch (trustDial) {
      case TrustDial.silent:
        return Duration.zero;
      case TrustDial.theater:
        return const Duration(milliseconds: 2400);
      case TrustDial.standard:
        const scheduleMs = <int>[2400, 1600, 800];
        if (launchCount < 1 || launchCount > scheduleMs.length) {
          return Duration.zero;
        }
        return Duration(milliseconds: scheduleMs[launchCount - 1]);
    }
  }

  void update(void Function() change) {
    change();
    notifyListeners();
  }
}
