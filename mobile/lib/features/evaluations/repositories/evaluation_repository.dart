import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_interceptor.dart';
import '../../../core/network/dio_client.dart';
import '../models/evaluation_model.dart';

class EvaluationRepository {
  Future<EvaluationModel> evaluer({
    required int trajetId,
    required String cibleId,
    required int note,
    String? commentaire,
  }) async {
    try {
      final body = <String, dynamic>{
        'trajet_id': trajetId,
        'cible_id': cibleId,
        'note': note,
      };
      if (commentaire != null) body['commentaire'] = commentaire;
      final response = await DioClient.post(ApiConstants.evaluer, data: body);
      return EvaluationModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<List<EvaluationModel>> mesEvaluations() async {
    try {
      final response = await DioClient.get(ApiConstants.mesEvaluations);
      return _parseList(response.data, 'mesEvaluations');
    } on DioException catch (e) {
      debugPrint('[EvalRepo] mesEvaluations error: $e');
      throw ApiException.fromDioException(e);
    }
  }

  Future<List<EvaluationModel>> mesEvaluationsEnvoyees() async {
    try {
      final response = await DioClient.get(ApiConstants.mesEvaluationsDonnees);
      return _parseList(response.data, 'mesEvaluationsDonnees');
    } on DioException catch (e) {
      debugPrint('[EvalRepo] mesEvaluationsDonnees error: $e');
      throw ApiException.fromDioException(e);
    }
  }

  List<EvaluationModel> _parseList(dynamic data, String tag) {
    debugPrint('[EvalRepo] $tag raw type: ${data.runtimeType}');
    if (data is List) {
      return data.map((e) => EvaluationModel.fromJson(e as Map<String, dynamic>)).toList();
    }
    if (data is Map && data['results'] is List) {
      return (data['results'] as List)
          .map((e) => EvaluationModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> aEvaluer() async {
    try {
      final response = await DioClient.get(ApiConstants.aEvaluer);
      final data = response.data;
      if (data is List) {
        return List<Map<String, dynamic>>.from(data);
      }
      return [];
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> signalerEvaluation({
    required String evaluationId,
    required String motif,
  }) async {
    try {
      await DioClient.post(
        ApiConstants.signaler,
        data: {'evaluation_id': evaluationId, 'motif': motif},
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> bloquerPassager(String passagerId) async {
    try {
      await DioClient.post(
        ApiConstants.bloquer,
        data: {'passager_id': passagerId},
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> debloquerPassager(String passagerId) async {
    try {
      await DioClient.delete('/evaluations/debloquer/$passagerId/');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
