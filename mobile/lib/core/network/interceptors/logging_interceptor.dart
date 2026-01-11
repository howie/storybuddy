import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../../constants/env.dart';

/// Interceptor that logs HTTP requests and responses.
class LoggingInterceptor extends Interceptor {
  LoggingInterceptor({Logger? logger})
      : _logger = logger ??
            Logger(
              printer: PrettyPrinter(
                methodCount: 0,
                errorMethodCount: 5,
                lineLength: 80,
              ),
            );

  final Logger _logger;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (!Env.isProduction) {
      _logger.d(
        '→ ${options.method} ${options.uri}\n'
        'Headers: ${_sanitizeHeaders(options.headers)}\n'
        'Data: ${_truncateData(options.data)}',
      );
    }
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    if (!Env.isProduction) {
      _logger.d(
        '← ${response.statusCode} ${response.requestOptions.uri}\n'
        'Data: ${_truncateData(response.data)}',
      );
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _logger.e(
      '✗ ${err.requestOptions.method} ${err.requestOptions.uri}\n'
      'Error: ${err.message}\n'
      'Response: ${err.response?.data}',
    );
    handler.next(err);
  }

  /// Sanitizes headers to hide sensitive information.
  Map<String, dynamic> _sanitizeHeaders(Map<String, dynamic> headers) {
    final sanitized = Map<String, dynamic>.from(headers);

    // Hide sensitive headers
    const sensitiveKeys = ['Authorization', 'Cookie', 'X-Auth-Token'];
    for (final key in sensitiveKeys) {
      if (sanitized.containsKey(key)) {
        sanitized[key] = '***REDACTED***';
      }
    }

    return sanitized;
  }

  /// Truncates large data payloads for logging.
  String _truncateData(dynamic data) {
    if (data == null) return 'null';

    final str = data.toString();
    const maxLength = 500;

    if (str.length > maxLength) {
      return '${str.substring(0, maxLength)}... (truncated)';
    }

    return str;
  }
}

/// Provider for the logging interceptor.
final loggingInterceptorProvider = Provider<LoggingInterceptor>((ref) {
  return LoggingInterceptor();
});
