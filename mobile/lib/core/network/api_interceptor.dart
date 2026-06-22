import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../services/storage_service.dart';
import '../services/session_service.dart';

class AuthInterceptor extends Interceptor {
  final Dio _dio;
  bool _isRefreshing = false;
  final List<_RetryRequest> _pendingRequests = [];

  AuthInterceptor(this._dio);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await StorageService.getAccessToken();
    if (token != null && options.headers['Authorization'] == null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401) {
      final refreshToken = await StorageService.getRefreshToken();
      if (refreshToken == null) {
        await StorageService.clearAll();
        SessionService.signalExpired();
        handler.next(err);
        return;
      }

      if (_isRefreshing) {
        _pendingRequests.add(_RetryRequest(err.requestOptions, handler));
        return;
      }

      _isRefreshing = true;
      try {
        final response = await _dio.post(
          ApiConstants.refreshToken,
          data: {'refresh': refreshToken},
          options: Options(headers: {'Authorization': null}),
        );

        final newAccess = response.data['access'] as String;
        await StorageService.saveAccessToken(newAccess);
        // Sauvegarder le nouveau refresh token (ROTATE_REFRESH_TOKENS=True côté backend)
        final newRefresh = response.data['refresh'] as String?;
        if (newRefresh != null) {
          await StorageService.saveRefreshToken(newRefresh);
        }

        // Retenter la requête originale
        err.requestOptions.headers['Authorization'] = 'Bearer $newAccess';
        final retryResponse = await _dio.fetch(err.requestOptions);
        handler.resolve(retryResponse);

        // Retenter les requêtes en attente
        for (final pending in _pendingRequests) {
          pending.options.headers['Authorization'] = 'Bearer $newAccess';
          try {
            final r = await _dio.fetch(pending.options);
            pending.handler.resolve(r);
          } catch (e) {
            pending.handler.next(
              DioException(requestOptions: pending.options),
            );
          }
        }
        _pendingRequests.clear();
      } catch (_) {
        await StorageService.clearAll();
        SessionService.signalExpired();
        for (final pending in _pendingRequests) {
          pending.handler.next(
            DioException(requestOptions: pending.options),
          );
        }
        _pendingRequests.clear();
        handler.next(err);
      } finally {
        _isRefreshing = false;
      }
    } else {
      handler.next(err);
    }
  }
}

class _RetryRequest {
  final RequestOptions options;
  final ErrorInterceptorHandler handler;
  _RetryRequest(this.options, this.handler);
}

// Helper pour parser les erreurs Django DRF
class ApiException implements Exception {
  final int statusCode;
  final String message;
  final Map<String, dynamic>? errors;

  ApiException({
    required this.statusCode,
    required this.message,
    this.errors,
  });

  factory ApiException.fromDioException(DioException e) {
    final statusCode = e.response?.statusCode ?? 0;
    final data = e.response?.data;

    String message = 'Une erreur est survenue';
    Map<String, dynamic>? errors;

    if (data is Map<String, dynamic>) {
      if (data.containsKey('detail')) {
        message = data['detail'].toString();
      } else if (data.containsKey('non_field_errors')) {
        final nfe = data['non_field_errors'];
        message = nfe is List ? nfe.first.toString() : nfe.toString();
      } else {
        errors = data;
        final firstError = data.values.first;
        if (firstError is List && firstError.isNotEmpty) {
          message = firstError.first.toString();
        } else {
          message = firstError.toString();
        }
      }
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      message = 'Délai de connexion dépassé. Vérifiez votre connexion.';
    } else if (e.type == DioExceptionType.connectionError) {
      message = 'Impossible de se connecter au serveur.';
    }

    return ApiException(
      statusCode: statusCode,
      message: message,
      errors: errors,
    );
  }

  @override
  String toString() => message;
}
