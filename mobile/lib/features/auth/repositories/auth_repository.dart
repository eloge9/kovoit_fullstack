import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_interceptor.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/services/storage_service.dart';
import '../models/user_model.dart';

class AuthRepository {
  Future<Map<String, dynamic>> inscription(Map<String, dynamic> data) async {
    try {
      final response = await DioClient.post(
        ApiConstants.inscription,
        data: data,
        requireAuth: false,
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<Map<String, dynamic>> connexion({
    required String email,
    required String password,
  }) async {
    try {
      final response = await DioClient.post(
        ApiConstants.connexion,
        data: {'email': email, 'password': password},
        requireAuth: false,
      );
      final data = response.data as Map<String, dynamic>;

      // Sauvegarder les tokens
      if (data['access'] != null) {
        await StorageService.saveAccessToken(data['access'] as String);
      }
      if (data['refresh'] != null) {
        await StorageService.saveRefreshToken(data['refresh'] as String);
      }
      if (data['user'] != null) {
        final user = data['user'] as Map<String, dynamic>;
        await StorageService.saveUserId(user['id']?.toString() ?? '');
        await StorageService.saveUserRole(user['role']?.toString() ?? 'passager');
      }
      return data;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> deconnexion() async {
    try {
      final refresh = await StorageService.getRefreshToken();
      if (refresh != null) {
        await DioClient.post(
          ApiConstants.deconnexion,
          data: {'refresh': refresh},
        );
      }
    } catch (_) {
      // Ignorer les erreurs réseau lors du logout
    } finally {
      await StorageService.clearAll();
    }
  }

  Future<UserModel> getProfil() async {
    try {
      final response = await DioClient.get(ApiConstants.profil);
      return UserModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<UserModel> updateProfil(Map<String, dynamic> data) async {
    try {
      final response = await DioClient.patch(
        ApiConstants.profil,
        data: data,
      );
      return UserModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> changerMotDePasse({
    required String ancienMdp,
    required String nouveauMdp,
  }) async {
    try {
      await DioClient.post(
        ApiConstants.changePassword,
        data: {
          'ancien_mot_de_passe': ancienMdp,
          'nouveau_mot_de_passe': nouveauMdp,
        },
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> changerMode(String mode) async {
    try {
      await DioClient.post(
        ApiConstants.changerMode,
        data: {'mode': mode},
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> basculerRole() async {
    try {
      await DioClient.post(ApiConstants.basculerRole);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> envoyerSos({
    required double latitude,
    required double longitude,
    int? trajetId,
  }) async {
    try {
      await DioClient.post(
        ApiConstants.sos,
        data: {
          'latitude': latitude,
          'longitude': longitude,
          if (trajetId != null) 'trajet_id': trajetId,
        },
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
