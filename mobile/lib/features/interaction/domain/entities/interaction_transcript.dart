import 'package:freezed_annotation/freezed_annotation.dart';

part 'interaction_transcript.freezed.dart';
part 'interaction_transcript.g.dart';

/// T079 [US4] Create InteractionTranscript model.
///
/// Represents a transcript of an interaction session.
///
/// Contains the formatted text content of the conversation between
/// the child and AI during a story session.
@freezed
class InteractionTranscript with _$InteractionTranscript {
  const factory InteractionTranscript({
    required String id,
    required String sessionId,
    required String plainText, required String htmlContent, required int turnCount, required int totalDurationMs, required DateTime createdAt, String? storyTitle,
    DateTime? emailSentAt,
  }) = _InteractionTranscript;

  factory InteractionTranscript.fromJson(Map<String, dynamic> json) =>
      _$InteractionTranscriptFromJson(json);
}

/// Extension methods for InteractionTranscript.
extension InteractionTranscriptX on InteractionTranscript {
  /// Duration in minutes (rounded).
  int get durationMinutes => (totalDurationMs / 60000).round();

  /// Duration in seconds.
  double get durationSeconds => totalDurationMs / 1000;

  /// Formatted duration string.
  String get durationText {
    final minutes = durationMinutes;
    final seconds = (totalDurationMs % 60000) ~/ 1000;
    if (minutes > 0) {
      return '$minutes 分 $seconds 秒';
    }
    return '$seconds 秒';
  }

  /// Whether the transcript has been emailed.
  bool get wasEmailed => emailSentAt != null;

  /// Whether this is an empty transcript (no conversation).
  bool get isEmpty => turnCount == 0;
}

/// Summary view of a transcript for listing.
@freezed
class TranscriptSummary with _$TranscriptSummary {
  const factory TranscriptSummary({
    required String id,
    required String sessionId,
    required String storyId,
    required String storyTitle,
    required int turnCount,
    required int durationMs,
    required DateTime createdAt,
    DateTime? emailSentAt,
  }) = _TranscriptSummary;

  factory TranscriptSummary.fromJson(Map<String, dynamic> json) =>
      _$TranscriptSummaryFromJson(json);
}

/// Extension methods for TranscriptSummary.
extension TranscriptSummaryX on TranscriptSummary {
  /// Duration in minutes.
  int get durationMinutes => (durationMs / 60000).round();

  /// Formatted duration string.
  String get durationText {
    final minutes = durationMinutes;
    if (minutes > 0) {
      return '$minutes 分鐘';
    }
    return '${(durationMs / 1000).round()} 秒';
  }
}
