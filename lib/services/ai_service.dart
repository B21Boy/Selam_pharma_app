import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AIService {
  // safe environment helper copied from cloudnary service; prevents crash
  // when dotenv wasn't initialized earlier.
  static String _safeEnv(String key) {
    try {
      return dotenv.env[key] ?? '';
    } catch (_) {
      return '';
    }
  }

  final String apiKey = _safeEnv('AI_API_KEY');

  Future<String> getAIRecommendation(
    String prompt, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (apiKey.isEmpty) {
      return _fallbackMessage();
    }

    try {
      final uri = Uri.parse('https://api.openai.com/v1/chat/completions');
      final resp = await http
          .post(
            uri,
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': 'gpt-4o-mini',
              'messages': [
                {
                  'role': 'system',
                  'content':
                      'You are a pharmacy medicine recommendation assistant.',
                },
                {'role': 'user', 'content': prompt},
              ],
              'temperature': 0.3,
            }),
          )
          .timeout(timeout);

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final content = data['choices']?[0]?['message']?['content'];
        if (content is String && content.trim().isNotEmpty) {
          return content.trim();
        }
        return _fallbackMessage();
      } else if (resp.statusCode == 401) {
        return 'Invalid API key. Please check your configuration.';
      } else {
        return _fallbackMessage();
      }
    } catch (e) {
      return _fallbackMessage();
    }
  }

  String _fallbackMessage() =>
      'I’m not confident recommending a medicine. Please consult a pharmacist or doctor.';
}
