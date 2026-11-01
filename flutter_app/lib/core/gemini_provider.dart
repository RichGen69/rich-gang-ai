import 'dart:convert';
import 'package:http/http.dart' as http;
import 'secure_keys.dart';
import 'settings.dart';

/// Google Gemini inference. VERIFIED against Google's API reference:
/// POST https://generativelanguage.googleapis.com/v1beta/models/
/// {model}:generateContent with the key in the `x-goog-api-key`
/// header (NOT a ?key= query parameter — keys do not belong in URLs),
/// body {"contents":[{"parts":[{"text": ...}]}]}, answer text in
/// candidates[0].content.parts[].text. Response parts flagged
/// `"thought": true` are the model's reasoning traces, not its
/// answer, and are skipped.
class GeminiProvider {
  static const base = 'https://generativelanguage.googleapis.com/v1beta';

  Future<bool> probe() async {
    final key = await SecureKeys.geminiKey;
    if (key == null || key.isEmpty) return false;
    try {
      final r = await http.get(
        Uri.parse('$base/models'),
        headers: {'x-goog-api-key': key},
      ).timeout(const Duration(seconds: 6));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<String> chat(String prompt, {String? grammar}) async {
    final key = await SecureKeys.geminiKey;
    if (key == null || key.isEmpty) {
      throw StateError('no Gemini API key configured');
    }
    if (grammar != null) {
      throw UnsupportedError(
          'GBNF grammar via the Gemini API is not supported - '
          'grammars run on the local engine path only');
    }
    final model = AppSettings.instance.geminiModel;
    final r = await http
        .post(
          Uri.parse('$base/models/$model:generateContent'),
          headers: {
            'x-goog-api-key': key,
            'Content-Type': 'application/json',
          },
          body: jsonEncode(<String, dynamic>{
            'contents': [
              {
                'parts': [
                  {'text': prompt}
                ]
              }
            ],
          }),
        )
        .timeout(const Duration(seconds: 60));
    if (r.statusCode != 200) {
      throw StateError('Gemini HTTP ${r.statusCode}: ${r.body}');
    }
    final decoded = jsonDecode(r.body) as Map<String, dynamic>;
    final candidates = decoded['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      throw StateError('Gemini returned no candidates: ${r.body}');
    }
    final content =
        (candidates.first as Map<String, dynamic>)['content']
            as Map<String, dynamic>;
    final parts = content['parts'] as List<dynamic>;
    final texts = <String>[
      for (final p in parts)
        if (p is Map<String, dynamic> &&
            p['thought'] != true &&
            p['text'] is String)
          p['text'] as String,
    ];
    if (texts.isEmpty) {
      throw StateError('Gemini returned no answer text: ${r.body}');
    }
    return texts.join();
  }
}
