import 'package:freezed_annotation/freezed_annotation.dart';

part 'interaction_settings.freezed.dart';

/// T084 [US4] Notification frequency options.
enum NotificationFrequency {
  /// Send email immediately after each session.
  instant,

  /// Send daily digest of all sessions.
  daily,

  /// Send weekly digest of all sessions.
  weekly,

  /// Do not send email notifications.
  none,
}

/// Domain entity for interaction settings.
/// Represents user preferences for the interactive story mode.
@freezed
class InteractionSettings with _$InteractionSettings {
  const factory InteractionSettings({
    /// Whether audio recording is enabled (FR-018).
    /// Default: false for privacy.
    @Default(false) bool recordingEnabled,

    /// Whether to automatically transcribe recordings.
    @Default(true) bool autoTranscribe,

    /// Number of days to retain recordings (FR-019).
    /// Default: 30 days.
    @Default(30) int retentionDays,

    /// T084 [US4] Whether email notifications are enabled.
    @Default(true) bool emailNotifications,

    /// T084 [US4] Notification frequency for transcript emails.
    @Default(NotificationFrequency.daily)
    NotificationFrequency notificationFrequency,

    /// T084 [US4] Email address for notifications.
    String? notificationEmail,
  }) = _InteractionSettings;
}

/// Extension methods for NotificationFrequency.
extension NotificationFrequencyX on NotificationFrequency {
  /// Display label in Chinese.
  String get displayName {
    switch (this) {
      case NotificationFrequency.instant:
        return '即時通知';
      case NotificationFrequency.daily:
        return '每日摘要';
      case NotificationFrequency.weekly:
        return '每週摘要';
      case NotificationFrequency.none:
        return '不通知';
    }
  }

  /// Description of the frequency.
  String get description {
    switch (this) {
      case NotificationFrequency.instant:
        return '每次互動結束後立即發送';
      case NotificationFrequency.daily:
        return '每天早上 9 點發送前一天的摘要';
      case NotificationFrequency.weekly:
        return '每週一早上 9 點發送上週摘要';
      case NotificationFrequency.none:
        return '不發送電子郵件通知';
    }
  }
}
