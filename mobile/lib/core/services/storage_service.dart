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

  // Identifiants sauvegardés ("Se souvenir de moi")
  static const _savedEmailKey = 'saved_email';
  static const _savedPasswordKey = 'saved_password';
  static const _rememberMeKey = 'remember_me';

  static Future<void> saveCredentials(String email, String password) async {
    await _storage.write(key: _savedEmailKey, value: email);
    await _storage.write(key: _savedPasswordKey, value: password);
    await _storage.write(key: _rememberMeKey, value: 'true');
  }

  static Future<({String email, String password})?> getSavedCredentials() async {
    final remember = await _storage.read(key: _rememberMeKey);
    if (remember != 'true') return null;
    final email = await _storage.read(key: _savedEmailKey);
    final password = await _storage.read(key: _savedPasswordKey);
    if (email == null || password == null) return null;
    return (email: email, password: password);
  }

  static Future<void> clearSavedCredentials() async {
    await _storage.delete(key: _savedEmailKey);
    await _storage.delete(key: _savedPasswordKey);
    await _storage.delete(key: _rememberMeKey);
  }

  // Mode actif (conducteur / passager)
  static const _activeModeKey = 'active_mode';

  static Future<void> saveActiveMode(String mode) =>
      _storage.write(key: _activeModeKey, value: mode);

  static Future<String?> getActiveMode() =>
      _storage.read(key: _activeModeKey);
}
