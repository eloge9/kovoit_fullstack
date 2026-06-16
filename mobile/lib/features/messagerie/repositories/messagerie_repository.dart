import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_interceptor.dart';
import '../../../core/network/dio_client.dart';
import '../models/message_model.dart';

class MessagerieRepository {
  Future<List<ConversationModel>> getConversations() async {
    try {
      final response = await DioClient.get(ApiConstants.conversations);
      final data = response.data;
      if (data is List) {
        return data.map((e) => ConversationModel.fromJson(e as Map<String, dynamic>)).toList();
      }
      return [];
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<List<MessageModel>> getMessages(int convId) async {
    try {
      final response = await DioClient.get('/messagerie/conversations/$convId/messages/');
      final data = response.data;
      if (data is List) {
        return data.map((e) => MessageModel.fromJson(e as Map<String, dynamic>)).toList();
      }
      return [];
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<MessageModel> envoyerMessage(int convId, String contenu) async {
    try {
      final response = await DioClient.post(
        '/messagerie/conversations/$convId/envoyer/',
        data: {'contenu': contenu},
      );
      return MessageModel.fromJson(response.data as Map<String, dynamic>);
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
