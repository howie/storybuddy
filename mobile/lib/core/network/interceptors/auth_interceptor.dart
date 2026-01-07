import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../storage/secure_storage_service.dart';

/// Interceptor that adds authentication headers to requests.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({required this.secureStorage});

  final SecureStorageService secureStorage;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Get the stored auth token
    final token = await secureStorage.getAuthToken();

    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    // Get the parent ID if available
    final parentId = await secureStorage.getParentId();
    if (parentId != null && parentId.isNotEmpty) {
      options.headers['X-Parent-ID'] = parentId;
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Handle 401 Unauthorized errors
    if (err.response?.statusCode == 401) {
      // Token might be expired, clear it
      secureStorage.clearAuthToken();
    }

    handler.next(err);
  }
}

/// Provider for the auth interceptor.
final authInterceptorProvider = Provider<AuthInterceptor>((ref) {
  final secureStorage = ref.watch(secureStorageServiceProvider);
  return AuthInterceptor(secureStorage: secureStorage);
});
