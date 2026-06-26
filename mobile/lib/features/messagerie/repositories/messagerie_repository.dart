import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_interceptor.dart';
import '../../../core/network/dio_client.dart';
import '../models/message_model.dart';

class MessagerieRepository {
  Future<List<ConversationModel>> getConversations() async {
    try {
      final response = await DioClient.get(ApiConstants.conversations);
      final data = response.data;
      debugPrint('[MessagerieRepo] getConversations raw type: ${data.runtimeType}');
      if (data is List) {
        debugPrint('[MessagerieRepo] getConversations: ${data.length} conversations');
        if (data.isNotEmpty) debugPrint('[MessagerieRepo] première conv: ${data.first}');
        return data.map((e) => ConversationModel.fromJson(e as Map<String, dynamic>)).toList();
      }
      debugPrint('[MessagerieRepo] getConversations: réponse inattendue: $data');
      return [];
    } on DioException catch (e) {
      debugPrint('[MessagerieRepo] getConversations error: $e');
      throw ApiException.fromDioException(e);
    }
  }

  Future<List<MessageModel>> getMessages(int convId) async {
    try {
      final response = await DioClient.get('/messagerie/conversations/$convId/messages/');
      final data = response.data;
      debugPrint('[MessagerieRepo] getMessages($convId) raw type: ${data.runtimeType}');
      if (data is List) {
        debugPrint('[MessagerieRepo] getMessages: ${data.length} messages');
        return data.map((e) => MessageModel.fromJson(e as Map<String, dynamic>)).toList();
      }
      debugPrint('[MessagerieRepo] getMessages: réponse inattendue: $data');
      return [];
    } on DioException catch (e) {
      debugPrint('[MessagerieRepo] getMessages error: $e');
      throw ApiException.fromDioException(e);
    }
  }

  Future<MessageModel> envoyerMessage(int convId, String contenu) async {
    try {
      final response = await DioClient.post(
        '/messagerie/conversations/$convId/envoyer/',
        data: {'contenu': contenu},
      );
      final raw = response.data;
      if (raw is Map<String, dynamic>) return MessageModel.fromJson(raw);
      if (raw is Map) return MessageModel.fromJson(Map<String, dynamic>.from(raw));
      throw Exception('Réponse message inattendue: ${raw.runtimeType}');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

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
