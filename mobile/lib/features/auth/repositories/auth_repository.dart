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
      final body = response.data as Map<String, dynamic>;
      // Le backend renvoie { "utilisateur": {...}, "tokens": {"access":..., "refresh":...} }
      await _saveTokensFromBody(body);
      return body;
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
      await _saveTokensFromBody(data);
      return data;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> _saveTokensFromBody(Map<String, dynamic> data) async {
    final tokens = data['tokens'] as Map<String, dynamic>?;
    if (tokens != null) {
      if (tokens['access'] != null) {
        await StorageService.saveAccessToken(tokens['access'] as String);
      }
      if (tokens['refresh'] != null) {
        await StorageService.saveRefreshToken(tokens['refresh'] as String);
      }
    }
    final utilisateur = data['utilisateur'] as Map<String, dynamic>?;
    if (utilisateur != null) {
      await StorageService.saveUserId(utilisateur['id']?.toString() ?? '');
      await StorageService.saveUserRole(
        utilisateur['role']?.toString() ?? 'passager',
      );
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
      final response = await DioClient.patch(ApiConstants.profil, data: data);
      return UserModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> changerMotDePasse({
    required String ancienMdp,
    required String nouveauMdp,
    required String nouveauMdp2,
  }) async {
    try {
      await DioClient.post(
        ApiConstants.changePassword,
        data: {
          'current_password': ancienMdp,
          'new_password': nouveauMdp,
          'new_password2': nouveauMdp2,
        },
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<Map<String, dynamic>> changerMode(String mode) async {
    try {
      final response = await DioClient.post(
        ApiConstants.changerMode,
        data: {'mode': mode},
      );
      final data = response.data as Map<String, dynamic>;
      // Mettre à jour les tokens si nouveaux tokens renvoyés
      if (data['tokens'] != null) {
        await _saveTokensFromBody(data);
      }
      return data;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> basculerRole(Map<String, dynamic> data) async {
    try {
      await DioClient.post(ApiConstants.basculerRole, data: data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> demanderCodeReset(String email) async {
    try {
      await DioClient.post(
        '/utilisateurs/auth/demander-code/',
        data: {'email': email},
        requireAuth: false,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> reinitialisation({
    required String email,
    required String code,
    required String newPassword,
    required String newPassword2,
  }) async {
    try {
      await DioClient.post(
        '/utilisateurs/auth/reinitialisation/',
        data: {
          'email': email,
          'code': code,
          'new_password': newPassword,
          'new_password2': newPassword2,
        },
        requireAuth: false,
      );
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
          'trajet_id': ?trajetId,
        },
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
