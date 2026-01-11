import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/database/enums.dart';

part 'qa_session.freezed.dart';

/// QASession entity representing an interactive Q&A session after a story.
@freezed
class QASession with _$QASession {
  const factory QASession({
    /// Unique identifier.
    required String id,

    /// Story ID this session is for.
    required String storyId,

    /// Session start timestamp.
    required DateTime startedAt,

    /// Session status.
    @Default(QASessionStatus.active) QASessionStatus status,

    /// Number of messages in this session.
    @Default(0) int messageCount,

    /// Session end timestamp (if ended).
    DateTime? endedAt,

    /// Sync status for offline support.
    @Default(SyncStatus.synced) SyncStatus syncStatus,
  }) = _QASession;

  const QASession._();

  /// Creates a new session for a story.
  factory QASession.create({
    required String id,
    required String storyId,
  }) {
    return QASession(
      id: id,
      storyId: storyId,
      startedAt: DateTime.now(),
      syncStatus: SyncStatus.pendingSync,
    );
  }

  /// Maximum messages allowed per session.
  static const int maxMessages = 10;

  /// Warning threshold for message limit.
  static const int warningThreshold = 8;

  /// Returns true if the session is active.
  bool get isActive => status == QASessionStatus.active;

  /// Returns true if the session has ended.
  bool get isEnded =>
      status == QASessionStatus.completed || status == QASessionStatus.timeout;

  /// Returns true if the message limit has been reached.
  bool get hasReachedLimit => messageCount >= maxMessages;

  /// Returns true if approaching the message limit.
  bool get isNearLimit =>
      messageCount >= warningThreshold && messageCount < maxMessages;

  /// Returns the number of remaining messages.
  int get remainingMessages =>
      (maxMessages - messageCount).clamp(0, maxMessages);

  /// Returns true if the session has pending local changes.
  bool get hasPendingChanges => syncStatus == SyncStatus.pendingSync;

  /// Returns the session duration.
  Duration get duration {
    final end = endedAt ?? DateTime.now();
    return end.difference(startedAt);
  }

  /// Returns a display-friendly status label.
  String get statusLabel => switch (status) {
        QASessionStatus.active => '進行中',
        QASessionStatus.completed => '已結束',
        QASessionStatus.timeout => '已逾時',
      };
}
