import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/network/api_interceptor.dart';
import '../../../core/network/dio_client.dart';
import '../models/verification_model.dart';

class VerificationRepository {
  static const _base = '/verification/driver/verification/';

  Future<DriverVerificationStatus> getStatus() async {
    try {
      final r = await DioClient.get('${_base}status/');
      return DriverVerificationStatus.fromJson(r.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<List<DriverDocumentModel>> getDocuments() async {
    try {
      final r = await DioClient.get('${_base}profile/');
      final data = r.data as Map<String, dynamic>;
      final docs = data['documents'];
      if (docs is List) {
        return docs
            .map((e) => DriverDocumentModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<Map<String, dynamic>> startVerification() async {
    try {
      final r = await DioClient.post('${_base}start/');
      return r.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<DriverDocumentModel> uploadDocument(
    String docType,
    String filePath,
    String fileName,
  ) async {
    try {
      final formData = FormData.fromMap({
        'document_type': docType,
        'file': await MultipartFile.fromFile(filePath, filename: fileName),
      });
      final r = await DioClient.upload('${_base}documents/upload/', formData);
      return DriverDocumentModel.fromJson(r.data as Map<String, dynamic>);
    } on DioException catch (e) {
      debugPrint('[VerifRepo] uploadDocument error: $e');
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> deleteDocument(String docId) async {
    try {
      await DioClient.delete('$_base$docId/delete/');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
