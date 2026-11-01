import 'dart:convert';
import 'package:http/http.dart' as http;
import 'secure_keys.dart';
import 'settings.dart';

class NvidiaRateLimit implements Exception {
  NvidiaRateLimit(this.retryAfter);
  final Duration? retryAfter;
}

/// HTTP 402 or an account-level 403 from NVIDIA.
///
/// ACTUAL SOLUTION (docs/VERIFY.md): the master prompt called this
/// "credits exhausted" and assumed a 1,000–5,000 trial-credit system.
/// That system appears to have been replaced by unpublished, per-model
/// rate limits (~40 RPM) — there may be no credits to exhaust. So this
/// exception means only what the wire actually says: the account/key was
/// refused at account level. The router falls back to Ollama and backs
/// off for a bounded hour, then re-probes — it does NOT lock NVIDIA out
/// for 24 hours "until top-up", because that story is unverified.
/// Confirm the real terms on your own build.nvidia.com dashboard.
class NvidiaAccountBlocked implements Exception {
  NvidiaAccountBlocked(this.statusCode);
  final int statusCode;
  @override
  String toString() => 'NvidiaAccountBlocked(HTTP $statusCode)';
}

/// NVIDIA hosted inference (OpenAI-compatible).
/// Base: https://integrate.api.nvidia.com/v1
class NvidiaProvider {
  static const base = 'https://integrate.api.nvidia.com/v1';

  /// Cheap probe. NVIDIA cold TLS can take 6+ seconds: 6s timeout, not 3.
  /// Callers must cache the result for 30s (InferenceRouter does).
  Future<bool> probe() async {
    final key = await SecureKeys.nvidiaKey;
    if (key == null || key.isEmpty) return false;
    try {
      final r = await http.get(
        Uri.parse('$base/models'),
        headers: {'Authorization': 'Bearer $key'},
      ).timeout(const Duration(seconds: 6));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<String> chat(String prompt, {String? grammar}) async {
    final key = await SecureKeys.nvidiaKey;
    if (key == null || key.isEmpty) {
      throw StateError('no NVIDIA API key configured');
    }
    final body = <String, dynamic>{
      'model': AppSettings.instance.nvidiaModel,
      'messages': [
        {'role': 'user', 'content': prompt}
      ],
      'stream': false,
    };
    // Grammar-constrained decoding (interrogation, Milestone 9) is NOT
    // forwarded: a `grammar` field on NVIDIA's OpenAI-compatible endpoint
    // is undocumented and unverified (docs/VERIFY.md). Fail loudly rather
    // than send a guessed field and hope.
    if (grammar != null) {
      throw UnsupportedError(
          'GBNF grammar via NVIDIA /v1 is unverified - see docs/VERIFY.md');
    }

    final r = await http
        .post(
          Uri.parse('$base/chat/completions'),
          headers: {
            'Authorization': 'Bearer $key',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 60));

    if (r.statusCode == 429) {
      final ra = r.headers['retry-after'];
      throw NvidiaRateLimit(
          ra == null ? null : Duration(seconds: int.tryParse(ra) ?? 60));
    }
    if (r.statusCode == 402 || r.statusCode == 403) {
      // 402 / account-level 403: account or key refused. See
      // NvidiaAccountBlocked — do not assume a credit balance here.
      throw NvidiaAccountBlocked(r.statusCode);
    }
    if (r.statusCode != 200) {
      throw StateError('NVIDIA HTTP ${r.statusCode}: ${r.body}');
    }
    final decoded = jsonDecode(r.body) as Map<String, dynamic>;
    final choices = decoded['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      // A 200 with no choices used to crash on .first — fail
      // cleanly so the router fails over instead.
      throw StateError('NVIDIA returned no choices: ${r.body}');
    }
    final msg = (choices.first as Map<String, dynamic>)['message']
        as Map<String, dynamic>;
    return (msg['content'] as String?) ?? '';
  }
}
