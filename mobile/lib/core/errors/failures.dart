import 'package:freezed_annotation/freezed_annotation.dart';

part 'failures.freezed.dart';

/// Base class for all failures in the app.
@freezed
sealed class Failure with _$Failure {
  const Failure._();

  /// Server returned an error response.
  const factory Failure.server({
    required String message,
    int? statusCode,
    Map<String, dynamic>? details,
  }) = ServerFailure;

  /// Network error (no internet, timeout, etc.).
  const factory Failure.network({
    required String message,
    Exception? exception,
  }) = NetworkFailure;

  /// Local cache/database error.
  const factory Failure.cache({
    required String message,
    Exception? exception,
  }) = CacheFailure;

  /// Authentication error.
  const factory Failure.auth({
    required String message,
    @Default(false) bool isExpired,
  }) = AuthFailure;

  /// Validation error.
  const factory Failure.validation({
    required String message,
    Map<String, List<String>>? fieldErrors,
  }) = ValidationFailure;

  /// Permission denied error.
  const factory Failure.permission({
    required String message,
    String? permission,
  }) = PermissionFailure;

  /// Audio-related error.
  const factory Failure.audio({
    required String message,
    Exception? exception,
  }) = AudioFailure;

  /// File operation error.
  const factory Failure.file({
    required String message,
    String? path,
    Exception? exception,
  }) = FileFailure;

  /// Unknown/unexpected error.
  const factory Failure.unknown({
    required String message,
    Object? error,
    StackTrace? stackTrace,
  }) = UnknownFailure;

  /// Returns a user-friendly error message.
  String get userMessage => when(
        server: (message, statusCode, details) => '伺服器錯誤：$message',
        network: (message, exception) => '網路連線失敗，請檢查網路設定',
        cache: (message, exception) => '本地資料錯誤：$message',
        auth: (message, isExpired) =>
            isExpired ? '登入已過期，請重新登入' : '認證失敗：$message',
        validation: (message, fieldErrors) => '輸入驗證失敗：$message',
        permission: (message, permission) => '權限不足：$message',
        audio: (message, exception) => '音訊錯誤：$message',
        file: (message, path, exception) => '檔案操作失敗：$message',
        unknown: (message, error, stackTrace) => '發生未知錯誤，請稍後再試',
      );

  /// Returns true if this failure is recoverable.
  bool get isRecoverable => maybeWhen(
        network: (_, __) => true,
        auth: (_, isExpired) => isExpired,
        orElse: () => false,
      );
}
