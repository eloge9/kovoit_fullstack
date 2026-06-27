import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_interceptor.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/services/storage_service.dart';
import '../models/message_model.dart';

Future<String?> _getToken() => StorageService.getAccessToken();

class MessagerieRepository {
  // ── Conversations ─────────────────────────────────────────────────────────

  Future<List<ConversationModel>> getConversations() async {
    try {
      final response = await DioClient.get(ApiConstants.conversations);
      final data = response.data;
      if (data is List) {
        return data
            .map((e) => ConversationModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      debugPrint('[MessagerieRepo] getConversations error: $e');
      throw ApiException.fromDioException(e);
    }
  }

  // ── Messages ──────────────────────────────────────────────────────────────

  Future<List<MessageModel>> getMessages(int convId, {int? avantId}) async {
    try {
      final qs = avantId != null ? '?avant=$avantId' : '';
      final response =
          await DioClient.get('/messagerie/conversations/$convId/messages/$qs');
      final data = response.data;
      if (data is List) {
        return data
            .map((e) => MessageModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<MessageModel> envoyerMessage(
    int convId,
    String contenu, {
    int? replyToId,
  }) async {
    try {
      final body = {
        'contenu': contenu,
        if (replyToId != null) 'reply_to_id': replyToId,
      };
      final response = await DioClient.post(
        '/messagerie/conversations/$convId/envoyer/',
        data: body,
      );
      final raw = response.data;
      if (raw is Map<String, dynamic>) return MessageModel.fromJson(raw);
      if (raw is Map) return MessageModel.fromJson(Map<String, dynamic>.from(raw));
      throw Exception('Réponse inattendue: ${raw.runtimeType}');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<MessageModel> envoyerAudio(
    int convId,
    String filePath,
    int durationSeconds,
  ) async {
    try {
      final formData = FormData.fromMap({
        'audio': await MultipartFile.fromFile(filePath, filename: 'message.m4a'),
        'duration': durationSeconds.toString(),
      });
      final response = await DioClient.post(
        '/messagerie/conversations/$convId/audio/',
        data: formData,
      );
      final raw = response.data;
      if (raw is Map<String, dynamic>) return MessageModel.fromJson(raw);
      throw Exception('Réponse audio inattendue');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // ── Actions sur un message ────────────────────────────────────────────────

  Future<Map<String, dynamic>> modifierMessage(int msgId, String contenu) async {
    try {
      final response = await DioClient.patch(
        '/messagerie/messages/$msgId/',
        data: {'contenu': contenu},
      );
      final raw = response.data;
      if (raw is Map<String, dynamic>) return raw;
      if (raw is Map) return Map<String, dynamic>.from(raw);
      return {};
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<Map<String, dynamic>> supprimerMessage(
    int msgId, {
    required bool pourTous,
  }) async {
    try {
      final token = await _getToken();
      final response = await DioClient.instance.delete(
        '/messagerie/messages/$msgId/supprimer/',
        data: {'pour_tous': pourTous},
        options: Options(headers: {if (token != null) 'Authorization': 'Bearer $token'}),
      );
      final raw = response.data;
      if (raw is Map<String, dynamic>) return raw;
      if (raw is Map) return Map<String, dynamic>.from(raw);
      return {};
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<Map<String, dynamic>> reagirMessage(int msgId, String emoji) async {
    try {
      final response = await DioClient.post(
        '/messagerie/messages/$msgId/reagir/',
        data: {'emoji': emoji},
      );
      final raw = response.data;
      if (raw is Map<String, dynamic>) return raw;
      if (raw is Map) return Map<String, dynamic>.from(raw);
      return {};
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // ── Conversation privée permanente ───────────────────────────────────────

  Future<ConversationModel> getOrCreatePrivate(String userId) async {
    try {
      final response = await DioClient.post('/messagerie/private/$userId/');
      final raw = response.data;
      if (raw is Map<String, dynamic>) return ConversationModel.fromJson(raw);
      throw Exception('Réponse inattendue');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // ── Conversation groupe trajet ─────────────────────────────────────────────

  Future<ConversationModel> getOrCreateGroupeTrajet(int trajetId) async {
    try {
      final response = await DioClient.post('/messagerie/trajet/$trajetId/groupe/');
      final raw = response.data;
      if (raw is Map<String, dynamic>) return ConversationModel.fromJson(raw);
      throw Exception('Réponse inattendue');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<ConversationModel?> getGroupeTrajet(int trajetId) async {
    try {
      final response = await DioClient.get('/messagerie/trajet/$trajetId/groupe/');
      final raw = response.data;
      if (raw is Map<String, dynamic> && raw['exists'] == true) {
        return ConversationModel.fromJson(raw);
      }
      return null;
    } on DioException catch (_) {
      return null;
    }
  }

  // ── Non lus ───────────────────────────────────────────────────────────────

  Future<int> getNonLusCount() async {
    try {
      final response = await DioClient.get(ApiConstants.nonLus);
      final data = response.data;
      if (data is Map) {
        return data['count'] as int? ?? data['non_lus'] as int? ?? 0;
      }
      return 0;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
