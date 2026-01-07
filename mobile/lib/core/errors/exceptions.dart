/// Base class for all app exceptions.
abstract class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Exception thrown when a server request fails.
class ServerException extends AppException {
  const ServerException({
    required String message,
    this.statusCode,
    this.details,
  }) : super(message);

  final int? statusCode;
  final Map<String, dynamic>? details;
}

/// Exception thrown when there's no network connection.
class NetworkException extends AppException {
  const NetworkException({
    String message = 'No network connection',
    this.originalException,
  }) : super(message);

  final Exception? originalException;
}

/// Exception thrown when a cache operation fails.
class CacheException extends AppException {
  const CacheException({
    required String message,
    this.originalException,
  }) : super(message);

  final Exception? originalException;
}

/// Exception thrown when authentication fails.
class AuthException extends AppException {
  const AuthException({
    required String message,
    this.isTokenExpired = false,
  }) : super(message);

  final bool isTokenExpired;
}

/// Exception thrown when validation fails.
class ValidationException extends AppException {
  const ValidationException({
    required String message,
    this.fieldErrors,
  }) : super(message);

  final Map<String, List<String>>? fieldErrors;
}

/// Exception thrown when a required permission is denied.
class PermissionException extends AppException {
  const PermissionException({
    required String message,
    this.permission,
  }) : super(message);

  final String? permission;
}

/// Exception thrown when an audio operation fails.
class AudioException extends AppException {
  const AudioException({
    required String message,
    this.originalException,
  }) : super(message);

  final Exception? originalException;
}

/// Exception thrown when a file operation fails.
class FileException extends AppException {
  const FileException({
    required String message,
    this.path,
    this.originalException,
  }) : super(message);

  final String? path;
  final Exception? originalException;
}

/// Exception thrown when a resource is not found.
class NotFoundException extends AppException {
  const NotFoundException({
    required String message,
    this.resourceType,
    this.resourceId,
  }) : super(message);

  final String? resourceType;
  final String? resourceId;
}

/// Exception thrown when a request times out.
class TimeoutException extends AppException {
  const TimeoutException({
    String message = 'Request timed out',
    this.duration,
  }) : super(message);

  final Duration? duration;
}
