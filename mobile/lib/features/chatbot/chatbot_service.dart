import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/api_constants.dart';
import '../../core/services/storage_service.dart';

const _sessionKey = 'kovoit_chat_session';

class ChatMessage {
  final String role;    // "user" ou "assistant"
  final String content;
  const ChatMessage({required this.role, required this.content});

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

class ChatbotService {
  static final ChatbotService _instance = ChatbotService._();
  factory ChatbotService() => _instance;
  ChatbotService._();

  final _client = http.Client();

  Future<String> _getSessionId() async {
    final prefs = await SharedPreferences.getInstance();
    var sid = prefs.getString(_sessionKey);
    if (sid == null) {
      sid = '${DateTime.now().millisecondsSinceEpoch}-${UniqueKey().toString()}';
      await prefs.setString(_sessionKey, sid);
    }
    return sid;
  }

  Future<Map<String, String>> _buildHeaders() async {
    final token = await StorageService.getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Streaming SSE — retourne un Stream de chunks de texte.
  /// Yield d'abord le provider ("gemini"|"claude"), puis les morceaux de texte.
  Stream<String> streamMessage(
    String message,
    List<ChatMessage> history,
  ) async* {
    final sessionId = await _getSessionId();
    final uri = Uri.parse('${ApiConstants.baseUrl}/chat/stream/');

    final body = jsonEncode({
      'message':              message,
      'session_id':           sessionId,
      'conversation_history': history.map((m) => m.toJson()).toList(),
    });

    final request = http.Request('POST', uri);
    request.headers.addAll(await _buildHeaders());
    request.body = body;

    try {
      final response = await _client.send(request).timeout(
        const Duration(seconds: 25),
      );

      if (response.statusCode != 200) {
        yield '[ERROR]Erreur serveur (${response.statusCode})';
        return;
      }

      final stream = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final line in stream) {
        if (!line.startsWith('data: ')) continue;
        final raw = line.substring(6).trim();
        if (raw.isEmpty) continue;

        try {
          final json = jsonDecode(raw) as Map<String, dynamic>;
          if (json['provider'] != null) {
            yield '[PROVIDER:${json['provider']}]';
          } else if (json['text'] != null) {
            // Remettre les newlines
            yield (json['text'] as String).replaceAll(r'\n', '\n');
          } else if (json['done'] == true) {
            yield '[DONE]';
            break;
          }
        } catch (e) {
          debugPrint('[Chatbot] Chunk malformé: $e');
        }
      }
    } on TimeoutException {
      yield '[ERROR]La réponse prend trop de temps. Vérifiez votre connexion.';
    } catch (e) {
      yield '[ERROR]Erreur réseau : vérifiez votre connexion internet.';
    }
  }
}
