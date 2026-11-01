import 'dart:convert';
import 'package:http/http.dart' as http;
import 'settings.dart';

/// Ollama, OpenAI-compatible endpoint. VERIFIED: GET /v1/models and
/// POST /v1/chat/completions exist (docs.ollama.com/api/openai-compatibility).
/// Default base http://127.0.0.1:11434/v1 is the PHONE itself on Android,
/// not the dev machine - set the laptop IP or run Ollama in Termux.
class OllamaProvider {
  String get base {
    var b = AppSettings.instance.ollamaBaseUrl.trim();
    if (b.endsWith('/')) b = b.substring(0, b.length - 1);
    return b;
  }

  Future<bool> probe() async {
    try {
      final r = await http
          .get(Uri.parse('$base/models'))
          .timeout(const Duration(seconds: 3));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<String> chat(String prompt, {String? grammar}) async {
    if (grammar != null) {
      // Milestone 9 gate (docs/VERIFY.md): GBNF grammar support via
      // Ollama's OpenAI-compatible endpoint is UNVERIFIED, and the earlier
      // draft silently forwarded a `grammar` field that endpoint is not
      // documented to accept. Fail loudly instead of guessing an API.
      throw UnsupportedError(
          'GBNF grammar via Ollama /v1 is unverified - see docs/VERIFY.md');
    }
    final body = <String, dynamic>{
      'model': AppSettings.instance.ollamaModel,
      'messages': [
        {'role': 'user', 'content': prompt}
      ],
      'stream': false,
    };

    final r = await http
        .post(
          Uri.parse('$base/chat/completions'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 120));
    if (r.statusCode != 200) {
      throw StateError('Ollama HTTP ${r.statusCode}: ${r.body}');
    }
    final decoded = jsonDecode(r.body) as Map<String, dynamic>;
    final choices = decoded['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      throw StateError('Ollama returned no choices: ${r.body}');
    }
    final msg = (choices.first as Map<String, dynamic>)['message']
        as Map<String, dynamic>;
    return (msg['content'] as String?) ?? '';
  }
}
