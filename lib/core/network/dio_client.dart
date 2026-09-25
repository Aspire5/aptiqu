import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Network Client configured with Dio, Secure Token Storage,
/// and 7-day Token Refresh Interceptor pointing directly to AWS instance.
class DioClient {
  static const String _accessTokenKey = 'aptiqu_access_token';
  static const String _refreshTokenKey = 'aptiqu_refresh_token';

  // Primary backend server URL
  static const String defaultBaseUrl = 'http://15.252.71.142:5001/api/v1';

  final FlutterSecureStorage secureStorage = const FlutterSecureStorage();
  late final Dio dio;

  // Callback to handle full session expiry (redirect to login)
  VoidCallback? onSessionExpired;

  DioClient({String? baseUrl}) {
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? defaultBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _setupInterceptors();
  }

  void _setupInterceptors() {
    dio.interceptors.add(
      QueuedInterceptorsWrapper(
        onRequest: (options, handler) async {
          // Attach Access Token if available
          final accessToken = await getAccessToken();
          if (accessToken != null && accessToken.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $accessToken';
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          return handler.next(response);
        },
        onError: (DioException error, handler) async {
          // If 401 Unauthorized, attempt 7-day refresh token rotation
          if (error.response?.statusCode == 401 &&
              !error.requestOptions.path.contains('/auth/refresh') &&
              !error.requestOptions.path.contains('/auth/google')) {
            try {
              final newTokens = await _performTokenRefresh();
              if (newTokens != null) {
                // Retry failed request with new access token
                final opts = error.requestOptions;
                opts.headers['Authorization'] = 'Bearer ${newTokens['accessToken']}';
                final cloneReq = await dio.fetch(opts);
                return handler.resolve(cloneReq);
              }
            } catch (_) {
              // Refresh failed: 7 days expired or revoked
              await clearTokens();
              onSessionExpired?.call();
            }
          }
          return handler.next(error);
        },
      ),
    );
  }

  Future<Map<String, String>?> _performTokenRefresh() async {
    final refreshToken = await getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return null;

    final response = await dio.post(
      '/auth/refresh',
      data: {'refreshToken': refreshToken},
    );

    if (response.statusCode == 200 && response.data['success'] == true) {
      final data = response.data['data'];
      final newAccessToken = data['accessToken'] as String;
      final newRefreshToken = data['refreshToken'] as String;

      await saveTokens(
        accessToken: newAccessToken,
        refreshToken: newRefreshToken,
      );

      return {
        'accessToken': newAccessToken,
        'refreshToken': newRefreshToken,
      };
    }
    return null;
  }

  // Secure Token Storage Methods
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await secureStorage.write(key: _accessTokenKey, value: accessToken);
    await secureStorage.write(key: _refreshTokenKey, value: refreshToken);
  }

  Future<String?> getAccessToken() async {
    return await secureStorage.read(key: _accessTokenKey);
  }

  Future<String?> getRefreshToken() async {
    return await secureStorage.read(key: _refreshTokenKey);
  }

  Future<void> clearTokens() async {
    await secureStorage.delete(key: _accessTokenKey);
    await secureStorage.delete(key: _refreshTokenKey);
  }
}
