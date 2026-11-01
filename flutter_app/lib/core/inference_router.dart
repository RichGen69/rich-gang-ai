import 'gemini_provider.dart';
import 'nvidia_provider.dart';
import 'ollama_provider.dart';
import 'openai_provider.dart';
import 'rpm_limiter.dart';
import 'settings.dart';
import 'tier10_system_controller.dart';

enum InferenceTask {
  personaDialogue,
  dreamBroadcast,
  interrogation,
  embeddings,
  intentClassification,
  idleBanter,
}

/// Task-aware routing - not a single blind fallback.
///
/// | Task                  | Primary       | Fallback      |
/// | persona dialogue      | NVIDIA        | Ollama        |
/// | dream broadcast text  | NVIDIA        | Ollama        |
/// | interrogation lines   | NVIDIA (GBNF) | Ollama (GBNF) |
/// | embeddings            | Local only    | -             |
/// | intent classification | Local only    | -             |
/// | idle banter           | Local only    | -             |
///
/// Local-only tasks NEVER send embeddings, intent data or conversation
/// history to a cloud provider. Only the single routed prompt is sent.
///
/// Accuracy note (2026-10-21): no learned embedding model is bundled in
/// this build. The `embeddings` task name is the spec's routing slot;
/// what actually runs locally today is Rust-side lexical hash vectors
/// (see rich_gang_ai_core/src/vector.rs) — token-overlap math, honestly
/// labelled, never presented as semantic embeddings.
class InferenceRouter {
  /// Shared instance: Settings clears this router's NVIDIA back-off when
  /// a key is saved, and chat/dream callers must use this same instance
  /// for that clearing to mean anything.
  static final InferenceRouter shared = InferenceRouter();

  InferenceRouter({
    NvidiaProvider? nvidia,
    OllamaProvider? ollama,
    OpenAiProvider? openAi,
    GeminiProvider? gemini,
    RpmLimiter? rpm,
    Tier10SystemController? tier10,
  })  : _tier10 = tier10 ?? Tier10SystemController(),
        _nvidia = nvidia ?? NvidiaProvider(),
        _ollama = ollama ?? OllamaProvider(),
        _openAi = openAi ?? OpenAiProvider(),
        _gemini = gemini ?? GeminiProvider(),
        _rpm = rpm ?? RpmLimiter();

  final NvidiaProvider _nvidia;
  final OllamaProvider _ollama;
  final OpenAiProvider _openAi;
  final GeminiProvider _gemini;
  final RpmLimiter _rpm;

  /// Tier-10 telemetry sink (2026-10-21). A caller may inject a
  /// shared instance; otherwise each router owns one, reachable via
  /// [tier10Controller] — existing callers and tests are unaffected
  /// either way (a controller with no listeners is a plain object).
  /// The router reports REAL measured cloud latencies, cloud
  /// failures, and local-Ollama fallback activations to it. It never
  /// reports a number it did not measure.
  final Tier10SystemController? _tier10;
  Tier10SystemController? get tier10Controller => _tier10;

  /// The router's fallback path: local Ollama. Activating it is a
  /// real routing event, so the Tier-10 controller trips to its
  /// edge state (whose docs state plainly that "edge" here means
  /// this Ollama fallback — no on-device LLM runtime is linked).
  Future<String> _ollamaFallback(String prompt, {String? grammar}) {
    _tier10?.tripToEdge();
    return _ollama.chat(prompt, grammar: grammar);
  }

  DateTime? _cooldownUntil;
  int _rateLimitStreak = 0;

  // Health-check cache: probe each provider at most once per 30 seconds.
  DateTime? _nvidiaProbedAt;
  bool _nvidiaUp = false;
  DateTime? _ollamaProbedAt;
  bool _ollamaUp = false;
  DateTime? _openAiProbedAt;
  bool _openAiUp = false;
  DateTime? _geminiProbedAt;
  bool _geminiUp = false;

  Future<bool> _probeOpenAi() async {
    final at = _openAiProbedAt;
    if (at != null && DateTime.now().difference(at).inSeconds < 30) {
      return _openAiUp;
    }
    _openAiUp = await _openAi.probe();
    _openAiProbedAt = DateTime.now();
    return _openAiUp;
  }

  Future<bool> _probeGemini() async {
    final at = _geminiProbedAt;
    if (at != null && DateTime.now().difference(at).inSeconds < 30) {
      return _geminiUp;
    }
    _geminiUp = await _gemini.probe();
    _geminiProbedAt = DateTime.now();
    return _geminiUp;
  }

  static bool _isLocalOnly(InferenceTask t) =>
      t == InferenceTask.embeddings ||
      t == InferenceTask.intentClassification ||
      t == InferenceTask.idleBanter;

  Future<bool> _probeNvidia() async {
    final at = _nvidiaProbedAt;
    if (at != null && DateTime.now().difference(at).inSeconds < 30) {
      return _nvidiaUp;
    }
    _nvidiaUp = await _nvidia.probe();
    _nvidiaProbedAt = DateTime.now();
    return _nvidiaUp;
  }

  Future<bool> _probeOllama() async {
    final at = _ollamaProbedAt;
    if (at != null && DateTime.now().difference(at).inSeconds < 30) {
      return _ollamaUp;
    }
    _ollamaUp = await _ollama.probe();
    _ollamaProbedAt = DateTime.now();
    return _ollamaUp;
  }

  Future<String> run(InferenceTask task, String prompt,
      {String? grammar}) async {
    if (_isLocalOnly(task)) {
      return _ollama.chat(prompt, grammar: grammar);
    }

    // Alternate cloud primaries (Richard, 2026-10-21): when Settings
    // selects OpenAI or Gemini, that provider is tried first with the
    // same probe-then-fallback shape as NVIDIA. A grammar request is
    // NOT silently downgraded — the provider's UnsupportedError
    // propagates, exactly as it does on the NVIDIA path's retry.
    final selected = AppSettings.instance.cloudProvider;
    if (selected == 'openai' || selected == 'gemini') {
      final up =
          selected == 'openai' ? await _probeOpenAi() : await _probeGemini();
      if (up) {
        final sw = Stopwatch()..start();
        try {
          final out = selected == 'openai'
              ? await _openAi.chat(prompt, grammar: grammar)
              : await _gemini.chat(prompt, grammar: grammar);
          sw.stop();
          _tier10?.recordCloudSuccess(sw.elapsed);
          return out;
        } on UnsupportedError {
          rethrow;
        } catch (e) {
          // Provider failed mid-call: fall through to local Ollama.
          _tier10?.recordCloudFailure(e);
        }
      }
      return _ollamaFallback(prompt, grammar: grammar);
    }

    final cooling = _cooldownUntil != null &&
        DateTime.now().isBefore(_cooldownUntil!);
    if (!cooling && await _probeNvidia()) {
      // RPM gate is checked BEFORE the call, per spec.
      if (!_rpm.acquire()) {
        return _ollamaFallback(prompt, grammar: grammar);
      }
      final sw = Stopwatch()..start();
      try {
        final out = await _nvidia.chat(prompt, grammar: grammar);
        sw.stop();
        _tier10?.recordCloudSuccess(sw.elapsed);
        _rateLimitStreak = 0;
        return out;
      } on NvidiaRateLimit catch (e) {
        _tier10?.recordCloudFailure(e);
        // Honor Retry-After, else 60 -> 120 -> 240, capped at 15 minutes.
        _rateLimitStreak++;
        final secs = [60, 120, 240][
            _rateLimitStreak > 3 ? 2 : _rateLimitStreak - 1];
        _cooldownUntil = DateTime.now()
            .add(e.retryAfter ?? Duration(seconds: secs > 900 ? 900 : secs));
        return _ollamaFallback(prompt, grammar: grammar);
      } on NvidiaAccountBlocked catch (e) {
        _tier10?.recordCloudFailure(e);
        // Account-level refusal (402 / account 403). Bounded 1-hour
        // back-off, then the normal health probe decides again — NOT a
        // 24-hour "credits exhausted" lockout: NVIDIA's trial terms
        // appear to have replaced credits with rate limits, and the
        // credit story is unverified (docs/VERIFY.md). Entering a new
        // key in Settings also clears this via clearNvidiaCooldown().
        _cooldownUntil = DateTime.now().add(const Duration(hours: 1));
        return _ollamaFallback(prompt, grammar: grammar);
      } catch (e) {
        _tier10?.recordCloudFailure(e);
        // Network error: one retry after 2s, then fall through to Ollama.
        await Future<void>.delayed(const Duration(seconds: 2));
        final sw2 = Stopwatch()..start();
        try {
          final out = await _nvidia.chat(prompt, grammar: grammar);
          sw2.stop();
          _tier10?.recordCloudSuccess(sw2.elapsed);
          return out;
        } catch (e) {
          _tier10?.recordCloudFailure(e);
          return _ollamaFallback(prompt, grammar: grammar);
        }
      }
    }
    return _ollamaFallback(prompt, grammar: grammar);
  }

  /// Clears any NVIDIA back-off. Settings calls this after the user
  /// enters or replaces an API key, so a fresh key is tried immediately
  /// instead of waiting out a cooldown earned by the old one.
  void clearNvidiaCooldown() {
    _cooldownUntil = null;
    _nvidiaProbedAt = null;
    _rateLimitStreak = 0;
  }

  /// Exposed for settings/diagnostics.
  Future<bool> ollamaReachable() => _probeOllama();
}
