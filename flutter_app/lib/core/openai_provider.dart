import 'dart:convert';
import 'package:http/http.dart' as http;
import 'secure_keys.dart';
import 'settings.dart';

/// OpenAI hosted inference (standard chat-completions API).
/// Base: https://api.openai.com/v1
///
/// Default model is GPT-6 Astra (see AppSettings.openAiModel) — the
/// slug is a setting, not a constant, because hosted model IDs rotate
/// and the exact ID must be confirmed in the OpenAI dashboard. API
/// errors are surfaced verbatim; nothing is retried silently or
/// answered locally on failure (the router decides fallbacks).
class OpenAiProvider {
  static const base = 'https://api.openai.com/v1';

  Future<bool> probe() async {
    final key = await SecureKeys.openAiKey;
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
    final key = await SecureKeys.openAiKey;
    if (key == null || key.isEmpty) {
      throw StateError('no OpenAI API key configured');
    }
    // GBNF is a llama.cpp grammar format; OpenAI's API has no GBNF
    // parameter. Same rule as the other hosted providers: fail loudly
    // instead of forwarding a guessed field.
    if (grammar != null) {
      throw UnsupportedError(
          'GBNF grammar via the OpenAI API is not supported - '
          'grammars run on the local engine path only');
    }
    final r = await http
        .post(
          Uri.parse('$base/chat/completions'),
          headers: {
            'Authorization': 'Bearer $key',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(<String, dynamic>{
            'model': AppSettings.instance.openAiModel,
            'messages': [
              {'role': 'user', 'content': prompt}
            ],
            'stream': false,
          }),
        )
        .timeout(const Duration(seconds: 60));
    if (r.statusCode != 200) {
      throw StateError('OpenAI HTTP ${r.statusCode}: ${r.body}');
    }
    final decoded = jsonDecode(r.body) as Map<String, dynamic>;
    final choices = decoded['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      throw StateError('OpenAI returned no choices: ${r.body}');
    }
    final msg = (choices.first as Map<String, dynamic>)['message']
        as Map<String, dynamic>;
    return (msg['content'] as String?) ?? '';
  }
}
