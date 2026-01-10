/// Environment configuration for the StoryBuddy app.
///
/// Values are injected at compile time via --dart-define flags.
abstract class Env {
  /// Base URL for the backend API.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8001/api/v1',
  );

  /// Whether the app is running in production mode.
  static const bool isProduction = bool.fromEnvironment(
    'PRODUCTION',
  );

  /// Connection timeout for API requests in seconds.
  static const int connectTimeoutSeconds = int.fromEnvironment(
    'CONNECT_TIMEOUT',
    defaultValue: 30,
  );

  /// Receive timeout for API requests in seconds.
  static const int receiveTimeoutSeconds = int.fromEnvironment(
    'RECEIVE_TIMEOUT',
    defaultValue: 30,
  );

  /// Maximum voice recording duration in seconds.
  static const int maxRecordingDurationSeconds = 180;

  /// Minimum voice recording duration in seconds.
  static const int minRecordingDurationSeconds = 30;

  /// Maximum story content length in characters.
  static const int maxStoryContentLength = 5000;

  /// Maximum Q&A messages per session.
  static const int maxQAMessages = 10;
}
