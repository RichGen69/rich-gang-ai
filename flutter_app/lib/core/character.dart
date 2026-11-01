import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

/// Character roles Richard asked for in this build.
/// A character can carry several: Dan is butler AND conversational,
/// Crazy Kelly is companion AND conversational.
enum CharacterRole {
  butler,
  companion,
  conversational,
  host,
  advisor,
  security,
  oracle,
  tech,
  unhinged,
  research,
  strategy,
  analysis,
  operator
}

CharacterRole? roleFromName(String n) {
  for (final r in CharacterRole.values) {
    if (r.name == n) return r;
  }
  return null;
}

/// One agent's voice casting. Three layers, in priority order:
/// 1. ElevenLabs neural voice ([elevenLabsVoiceId]) — the premium,
///    most human-like path, used when Richard has put an ElevenLabs
///    key in secure storage.
/// 2. Kokoro voice name ([kokoroVoice]) — the casting for the
///    on-device Kokoro path. That path is NOT wired in this build
///    (Kokoro Flutter packages were assessed immature in
///    docs/BUILD_SESSION_2026-10-21c.md; sherpa_onnx is the credible
///    evaluation route). The name is kept so casting survives the
///    switch; nothing claims Kokoro audio plays today.
/// 3. System TTS ([systemPitch]/[systemRate]) — the device engine via
///    flutter_tts. Quality is whatever the phone's engine is; the app
///    labels it as such and never as "indistinguishable".
class VoiceCasting {
  const VoiceCasting({
    required this.display,
    required this.elevenLabsVoiceId,
    required this.elevenLabsVoiceName,
    required this.kokoroVoice,
    required this.systemPitch,
    required this.systemRate,
    required this.stability,
    required this.style,
  });

  final String display;
  final String elevenLabsVoiceId;
  final String elevenLabsVoiceName;
  final String kokoroVoice;
  final double systemPitch;
  final double systemRate;

  /// ElevenLabs voice_settings: lower stability = more emotional
  /// variation, higher style = more exaggerated delivery (v2 only).
  /// The affect engine modulates these per utterance — see
  /// voice_engine.dart Prosody.
  final double stability;
  final double style;

  /// The uncast casting used for registry-only entries (Tier-10
  /// expansion, 2026-10-21): empty voice ids are the truth — no
  /// ElevenLabs voice and no Kokoro casting has been assigned.
  /// Numeric fields are neutral system-TTS defaults only; the empty
  /// ids are what callers/tests check via [isUncast].
  static const VoiceCasting uncast = VoiceCasting(
    display: 'Uncast — not configured',
    elevenLabsVoiceId: '',
    elevenLabsVoiceName: '',
    kokoroVoice: '',
    systemPitch: 1.0,
    systemRate: 0.5,
    stability: 0.5,
    style: 0.0,
  );

  bool get isUncast => elevenLabsVoiceId.isEmpty && kokoroVoice.isEmpty;

  factory VoiceCasting.fromJson(Map<String, dynamic>? j) {
    if (j == null) return uncast;
    String s(String k) => j[k] as String? ?? '';
    double d(String k, double fallback) =>
        (j[k] as num?)?.toDouble() ?? fallback;
    return VoiceCasting(
      display: s('display'),
      elevenLabsVoiceId: s('eleven_labs_voice_id'),
      elevenLabsVoiceName: s('eleven_labs_voice_name'),
      kokoroVoice: s('kokoro_voice'),
      systemPitch: d('system_pitch', 1.0),
      systemRate: d('system_rate', 0.5),
      stability: d('stability', 0.5),
      style: d('style', 0.0),
    );
  }
}

/// A character's 3D avatar configuration for the Stage.
///
/// [modelSrc] is a glTF/GLB source exactly as model_viewer_plus
/// accepts it: a bundled asset path ("assets/models/x.glb"), an
/// https URL, or a file:// path. EMPTY means this character has no
/// 3D model yet — the Stage shows its honest no-model state; it
/// never substitutes another character's model or the demo robot
/// and calls it this character.
///
/// [animations] maps DIRECTOR SLOTS (idle, talk, and emotion names
/// from affect_engine's prototypes: joy, anger, sadness, …) to the
/// clip names INSIDE that character's own GLB. Slots are resolved
/// by StageDirector; a missing slot falls back to idle, then to no
/// forced animation.
class Avatar3DConfig {
  const Avatar3DConfig({required this.modelSrc, required this.animations});
  final String modelSrc;
  final Map<String, String> animations;

  bool get hasModel => modelSrc.trim().isNotEmpty;

  static Avatar3DConfig? fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final src = (raw['model_src'] as String? ?? '').trim();
    final anims = raw['animations'];
    return Avatar3DConfig(
      modelSrc: src,
      animations: anims is Map<String, dynamic>
          ? anims.map((k, v) => MapEntry(k, v.toString()))
          : const {},
    );
  }
}

/// A playable character, loaded from assets/characters.json — the
/// single source of truth for the roster. The Rust daemon only knows
/// the ids (its "personas" array); everything characterful lives here.
class CharacterDef {
  const CharacterDef({
    required this.id,
    required this.name,
    required this.displayName,
    required this.title,
    required this.roles,
    required this.core,
    required this.personality,
    required this.speechStyle,
    required this.interests,
    required this.talkativeness,
    required this.volatility,
    required this.baselinePleasure,
    required this.baselineArousal,
    required this.baselineDominance,
    required this.ageGated,
    required this.voice,
    this.avatar3d,
    this.portrait,
    this.zodiac,
    this.celestial,
    this.universe,
    this.moralCore,
    this.guardrails,
    this.selfKnowledge,
    this.toneSpec,
    this.toneByEmotion = const {},
    this.gifts = const {},
    this.status = 'configured',
  });

  final String id;
  final String name;
  final String displayName;
  final String title;
  final List<CharacterRole> roles;

  /// The evidenced core text (frame text / Richard's words), used
  /// verbatim in the prompt — never paraphrased into new claims.
  final String core;
  final String personality;
  final String speechStyle;
  final List<String> interests;

  /// 0..1 — how much this agent pushes to speak (roundtable scoring).
  final double talkativeness;

  /// 0..1 — how strongly events move this agent's affect.
  final double volatility;

  /// PAD baseline the affect state decays back toward.
  final double baselinePleasure;
  final double baselineArousal;
  final double baselineDominance;

  /// True for Crazy Kelly in the configured roster (21+; she
  /// replaced Cougar Kelly on 2026-10-21, confirmed 2026-10-22),
  /// and for Shawna and Ruby in the
  /// 22-agent expansion (Richard-supplied, 2026-10-21). The UI must
  /// confirm the gate before this character can be selected or
  /// added to a roundtable. NOTE: the gate is confirmation-only
  /// (see views/character_ui.dart AgeGate) — it is NOT verified
  /// age assurance and no JWT/biometric check backs it.
  final bool ageGated;

  /// Zodiac sign where Richard's roster assigns one (e.g. 'Aries'),
  /// else null.
  final String? zodiac;

  /// Celestial alignment where Richard's roster assigns one instead
  /// of a zodiac sign (e.g. 'Chronos', 'Aether'), else null.
  final String? celestial;

  /// Home universe where Richard supplied one (e.g. 'Ashfall-77'),
  /// else null. Never invented for entries Richard did not give one.
  final String? universe;

  /// 'configured' for the original nine (voice, baseline, portrait
  /// all present). 'registry_only_unconfigured' for the 13 Tier-10
  /// expansion entries: they exist in the registry ONLY — no voice
  /// casting, no affect baseline, and no portrait have been
  /// configured, and the UI must surface that instead of presenting
  /// parser defaults as real configuration.
  ///
  /// 'configured_voice_uncast' is Danny's tier (flagship promotion,
  /// 2026-10-23): baseline, talkativeness, volatility and portrait
  /// are all configured and he leads the roster, but his ElevenLabs
  /// voice is honestly UNCAST — every premade voice documented in
  /// this project is already cast to the nine, inventing an id is
  /// forbidden, and casting waits on Richard's pick from his own
  /// account. He speaks through the system-TTS fallback with his
  /// own delivery profile until then, and every surface that shows
  /// his voice shows "Uncast — not configured".
  final String status;

  bool get isRegistryOnly => status == 'registry_only_unconfigured';

  /// True when the entry carries real configuration rather than
  /// existing only in the registry. Danny's
  /// `configured_voice_uncast` tier counts as configured here; his
  /// separate [VoiceCasting.isUncast] value remains the truth about
  /// voice casting.
  bool get isConfigured => !isRegistryOnly;

  /// True only for Danny's flagship tier: fully configured except
  /// voice casting (see [status]).
  bool get isConfiguredVoiceUncast => status == 'configured_voice_uncast';

  /// Danny's authored moral core (values, honesty, loyalty,
  /// responsibility, legality, conscience) — a definition section,
  /// immutable to Danny: the self-upgrade path rejects writes to it
  /// (see danny_upgrades.dart). Null for every other character.
  final String? moralCore;

  /// Danny's authored guardrail scope (allowlist, bounds,
  /// immutability, kill switch) — likewise definition-only and not
  /// writable through any self-upgrade path. Null for others.
  final String? guardrails;

  /// Danny's accurate self-account: what he is and is not (an
  /// on-device-orchestrated AI persona; no on-device LLM runtime;
  /// discernment = consistency-checking, not lie detection).
  /// Injected into his prompt so his self-descriptions stay
  /// truthful. Null for other characters.
  final String? selfKnowledge;

  /// Danny's tone-of-voice spec — register, pace, attitude — which
  /// doubles as his ElevenLabs casting brief for the day Richard
  /// casts him. Null for other characters.
  final String? toneSpec;

  /// Danny's emotion-conditioned tone table, keyed by the affect
  /// engine's emotion names (joy, anger, calm, …). The prompt
  /// builder looks up his CURRENT derived emotion here, so his
  /// register bends with his real state. Empty for others.
  final Map<String, String> toneByEmotion;

  /// Danny's named GIFTS endowment (the ledger, second sight,
  /// double-check, dream gifts, a conscience that talks back, the
  /// trophy shelf) — key → authored description. Each gift is
  /// implemented only as far as real machinery supports it; the
  /// docs (docs/DANNY_FLAGSHIP_MODEL_2026-10-23.md) state which
  /// are wired mechanisms and which are persona traits. Empty for
  /// other characters.
  final Map<String, String> gifts;
  String? get zodiacOrCelestial => zodiac ?? celestial;

  final VoiceCasting voice;

  /// 3D model config, or null when characters.json carries no
  /// "avatar3d" object for this character (the shipped state for
  /// all nine — no character GLBs exist yet).
  final Avatar3DConfig? avatar3d;

  /// Cinematic portrait asset path (assets/images/portraits/),
  /// generated for all nine on 2026-10-21 — this is the character's
  /// visual identity everywhere an avatar shows. A portrait is a
  /// portrait: it is NOT a 3D model and never pretends to be one.
  final String? portrait;

  factory CharacterDef.fromJson(Map<String, dynamic> j) {
    // Baseline is OPTIONAL: registry-only entries omit it entirely
    // rather than carrying a fabricated neutral PAD. The parser
    // defaults to 0.0 for the affect engine's arithmetic, but the
    // entry's [status] marks it unconfigured — those defaults must
    // never be presented as a configured affect profile.
    final b = j['baseline'] as Map<String, dynamic>?;
    double bd(String k) => (b?[k] as num?)?.toDouble() ?? 0.0;
    return CharacterDef(
      id: j['id'] as String,
      name: j['name'] as String,
      displayName: j['display_name'] as String? ?? j['name'] as String,
      title: j['title'] as String? ?? '',
      roles: [
        for (final r
            in ((j['roles'] as List<dynamic>?) ?? const []).cast<String>())
          if (roleFromName(r) != null) roleFromName(r)!,
      ],
      core: j['core'] as String? ?? '',
      personality: j['personality'] as String? ?? '',
      speechStyle: j['speech_style'] as String? ?? '',
      interests:
          ((j['interests'] as List<dynamic>?) ?? const []).cast<String>(),
      // Scoring defaults for registry-only entries (they omit these
      // keys); [status] is the source of truth that they are not
      // configured values.
      talkativeness: (j['talkativeness'] as num?)?.toDouble() ?? 0.5,
      volatility: (j['volatility'] as num?)?.toDouble() ?? 0.5,
      baselinePleasure: bd('pleasure'),
      baselineArousal: bd('arousal'),
      baselineDominance: bd('dominance'),
      ageGated: j['age_gated'] as bool? ?? false,
      moralCore: j['moral_core'] as String?,
      guardrails: j['guardrails'] as String?,
      selfKnowledge: j['self_knowledge'] as String?,
      toneSpec: j['tone'] as String?,
      toneByEmotion: (j['tone_by_emotion'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v.toString())) ??
          const {},
      gifts: (j['gifts'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v.toString())) ??
          const {},
      voice: VoiceCasting.fromJson(j['voice'] as Map<String, dynamic>?),
      avatar3d: Avatar3DConfig.fromJson(j['avatar3d']),
      portrait: j['portrait'] as String?,
      zodiac: j['zodiac'] as String?,
      celestial: j['celestial'] as String?,
      universe: j['universe'] as String?,
      status: j['status'] as String? ?? 'configured',
    );
  }
}

/// Loads and caches assets/characters.json. A load failure returns an
/// EMPTY registry — the app then shows an honest "no characters
/// loaded" state instead of inventing a roster.
class CharacterRegistry {
  CharacterRegistry(this._byId);
  final Map<String, CharacterDef> _byId;

  static CharacterRegistry? _cache;

  static Future<CharacterRegistry> load() async {
    if (_cache != null) return _cache!;
    try {
      final raw = await rootBundle.loadString('assets/characters.json');
      _cache = CharacterRegistry.parse(raw);
    } catch (_) {
      _cache = CharacterRegistry(const {});
    }
    return _cache!;
  }

  /// Pure parse — unit-testable without the asset bundle.
  static CharacterRegistry parse(String raw) {
    final doc = jsonDecode(raw) as Map<String, dynamic>;
    final list = (doc['characters'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(CharacterDef.fromJson)
        .toList();
    return CharacterRegistry({for (final c in list) c.id: c});
  }

  bool get isEmpty => _byId.isEmpty;
  List<CharacterDef> get all => _byId.values.toList();
  CharacterDef? byId(String id) => _byId[id];
  List<CharacterDef> byRole(CharacterRole role) =>
      all.where((c) => c.roles.contains(role)).toList();
}
