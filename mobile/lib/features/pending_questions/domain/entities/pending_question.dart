import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/database/enums.dart';

part 'pending_question.freezed.dart';

/// Entity representing an out-of-scope question from a Q&A session.
@freezed
class PendingQuestion with _$PendingQuestion {
  const factory PendingQuestion({
    required String id,
    required String storyId,
    required String question,
    required PendingQuestionStatus status,
    required DateTime askedAt,
    DateTime? answeredAt,
    @Default(SyncStatus.synced) SyncStatus syncStatus,
  }) = _PendingQuestion;

  const PendingQuestion._();

  /// Whether this question is still pending (not answered).
  bool get isPending => status == PendingQuestionStatus.pending;

  /// Whether this question has been answered.
  bool get isAnswered => status == PendingQuestionStatus.answered;

  /// Time since the question was asked.
  Duration get timeSinceAsked => DateTime.now().difference(askedAt);

  /// Human-readable time description.
  String get timeAgo {
    final duration = timeSinceAsked;
    if (duration.inDays > 0) {
      return '${duration.inDays} 天前';
    } else if (duration.inHours > 0) {
      return '${duration.inHours} 小時前';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes} 分鐘前';
    } else {
      return '剛才';
    }
  }
}

/// Summary of pending questions for a story.
@freezed
class PendingQuestionSummary with _$PendingQuestionSummary {
  const factory PendingQuestionSummary({
    required String storyId,
    required String storyTitle,
    required int pendingCount,
    DateTime? latestQuestionAt,
  }) = _PendingQuestionSummary;

  const PendingQuestionSummary._();

  /// Whether there are any pending questions.
  bool get hasPendingQuestions => pendingCount > 0;
}
