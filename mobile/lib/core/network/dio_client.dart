import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../services/storage_service.dart';
import 'api_interceptor.dart';

class DioClient {
  static Dio? _instance;

  static Dio get instance {
    _instance ??= _createDio();
    return _instance!;
  }

  static Dio _createDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.addAll([
      AuthInterceptor(dio),
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        error: true,
        logPrint: (obj) => debugLog(obj.toString()),
      ),
    ]);

    return dio;
  }

  // Appeler après ApiConstants.updateServerUrl() pour recréer l'instance
  static void reset() {
    _instance?.close();
    _instance = null;
  }

  static void debugLog(String message) {
    // ignore: avoid_print
    print('[DioClient] $message');
  }

  // GET
  static Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParams,
    bool requireAuth = true,
  }) async {
    final options = requireAuth ? await _authOptions() : null;
    return instance.get(path, queryParameters: queryParams, options: options);
  }

  // POST
  static Future<Response> post(
    String path, {
    dynamic data,
    bool requireAuth = true,
  }) async {
    final options = requireAuth ? await _authOptions() : null;
    return instance.post(path, data: data, options: options);
  }

  // PUT
  static Future<Response> put(
    String path, {
    dynamic data,
    bool requireAuth = true,
  }) async {
    final options = requireAuth ? await _authOptions() : null;
    return instance.put(path, data: data, options: options);
  }

  // PATCH
  static Future<Response> patch(
    String path, {
    dynamic data,
    bool requireAuth = true,
  }) async {
    final options = requireAuth ? await _authOptions() : null;
    return instance.patch(path, data: data, options: options);
  }

  // DELETE
  static Future<Response> delete(
    String path, {
    bool requireAuth = true,
  }) async {
    final options = requireAuth ? await _authOptions() : null;
    return instance.delete(path, options: options);
  }

  // Upload multipart
  static Future<Response> upload(
    String path,
    FormData formData, {
    bool requireAuth = true,
    ProgressCallback? onSendProgress,
  }) async {
    final token = requireAuth ? await StorageService.getAccessToken() : null;
    final headers = <String, dynamic>{
      if (token != null) 'Authorization': 'Bearer $token',
    };
    return instance.post(
      path,
      data: formData,
      options: Options(headers: headers),
      onSendProgress: onSendProgress,
    );
  }

  static Future<Options?> _authOptions() async {
    final token = await StorageService.getAccessToken();
    if (token == null) return null;
    return Options(headers: {'Authorization': 'Bearer $token'});
  }
}
