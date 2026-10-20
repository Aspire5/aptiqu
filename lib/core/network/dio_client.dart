import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Network Client configured with Dio, Secure Token Storage,
/// and 7-day Token Refresh Interceptor pointing directly to AWS instance.
class DioClient {
  static const String _accessTokenKey = 'aptiqu_access_token';
  static const String _refreshTokenKey = 'aptiqu_refresh_token';

  // Primary backend server URL (Enforce HTTPS with TLS)
  static const String defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://15.252.71.142/api/v1',
  );

  final FlutterSecureStorage secureStorage = const FlutterSecureStorage();
  late final Dio dio;

  // Callback to handle full session expiry (redirect to login)
  VoidCallback? onSessionExpired;

  DioClient({String? baseUrl}) {
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? defaultBaseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 90),
        sendTimeout: const Duration(seconds: 30),
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
      InterceptorsWrapper(
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
              !error.requestOptions.path.contains('/auth/google') &&
              error.requestOptions.extra['authRetried'] != true) {
            try {
              final newTokens = await refreshSession();
              if (newTokens != null) {
                // Retry failed request with new access token
                final opts = error.requestOptions;
                opts.extra['authRetried'] = true;
                opts.headers['Authorization'] =
                    'Bearer ${newTokens['accessToken']}';
                final cloneReq = await dio.fetch(opts);
                return handler.resolve(cloneReq);
              }
            } on DioException catch (refreshError) {
              if (refreshError.response?.statusCode == 401 ||
                  refreshError.response?.statusCode == 403) {
                await clearTokens();
                onSessionExpired?.call();
              }
              // Rate limits, outages and uncertain network results preserve local credentials.
            }
          }
          return handler.next(error);
        },
      ),
    );
  }

  Future<Map<String, String>?>? _refreshing;
  Future<Map<String, String>?> refreshSession() {
    final pending = _refreshing;
    if (pending != null) return pending;
    late final Future<Map<String, String>?> work;
    work = _performTokenRefresh().whenComplete(() {
      if (identical(_refreshing, work)) _refreshing = null;
    });
    _refreshing = work;
    return work;
  }

  Future<Map<String, String>?> _performTokenRefresh() async {
    final refreshToken = await getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return null;

    // Separate transport avoids waiting on this client's queued error interceptor.
    final transport = Dio(
      BaseOptions(
        baseUrl: dio.options.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );
    final response = await transport.post(
      '/auth/refresh',
      data: {'refreshToken': refreshToken},
    );

    if (response.statusCode == 200 && response.data['success'] == true) {
      final data = response.data['data'];
      final newAccessToken = data['accessToken'] as String;
      final newRefreshToken = data['refreshToken'] as String;

      if (await getRefreshToken() != refreshToken) return null;
      await saveTokens(
        accessToken: newAccessToken,
        refreshToken: newRefreshToken,
      );

      return {'accessToken': newAccessToken, 'refreshToken': newRefreshToken};
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
