import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';

class StorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const String _serverUrlKey = 'server_url';

  // Tokens JWT
  static Future<void> saveAccessToken(String token) =>
      _storage.write(key: AppConstants.accessTokenKey, value: token);

  static Future<void> saveRefreshToken(String token) =>
      _storage.write(key: AppConstants.refreshTokenKey, value: token);

  static Future<String?> getAccessToken() =>
      _storage.read(key: AppConstants.accessTokenKey);

  static Future<String?> getRefreshToken() =>
      _storage.read(key: AppConstants.refreshTokenKey);

  static Future<void> saveUserId(String id) =>
      _storage.write(key: AppConstants.userIdKey, value: id);

  static Future<String?> getUserId() =>
      _storage.read(key: AppConstants.userIdKey);

  static Future<void> saveUserRole(String role) =>
      _storage.write(key: AppConstants.userRoleKey, value: role);

  static Future<String?> getUserRole() =>
      _storage.read(key: AppConstants.userRoleKey);

  static Future<void> clearAll() => _storage.deleteAll();

  static Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  // URL du serveur Django
  static Future<void> saveServerUrl(String url) =>
      _storage.write(key: _serverUrlKey, value: url);

  static Future<String?> getServerUrl() =>
      _storage.read(key: _serverUrlKey);

  static Future<void> clearServerUrl() =>
      _storage.delete(key: _serverUrlKey);
}
