import 'package:freezed_annotation/freezed_annotation.dart';

part 'ai_response.freezed.dart';
part 'ai_response.g.dart';

/// What triggered an AI response.
enum TriggerType {
  childSpeech,
  storyPrompt,
  timeout,
}

/// Represents an AI response during interaction.
///
/// An AIResponse captures the AI's reply to child speech or a story prompt,
/// including the generated text and optional audio.
@freezed
class AIResponse with _$AIResponse {
  const factory AIResponse({
    required String id,
    required String sessionId,
    String? voiceSegmentId,
    required String text,
    String? audioUrl,
    required TriggerType triggerType,
    @Default(false) bool wasInterrupted,
    int? interruptedAtMs,
    required int responseLatencyMs,
    required DateTime createdAt,
  }) = _AIResponse;

  factory AIResponse.fromJson(Map<String, dynamic> json) =>
      _$AIResponseFromJson(json);
}

/// Extension methods for AIResponse.
extension AIResponseX on AIResponse {
  /// Whether this response was triggered by child speech.
  bool get isFromChildSpeech => triggerType == TriggerType.childSpeech;

  /// Whether this response has audio.
  bool get hasAudio => audioUrl != null && audioUrl!.isNotEmpty;

  /// Response latency as Duration.
  Duration get latency => Duration(milliseconds: responseLatencyMs);

  /// Percentage of response played before interruption (if interrupted).
  double? interruptionPercentage(int totalDurationMs) {
    if (!wasInterrupted || interruptedAtMs == null || totalDurationMs == 0) {
      return null;
    }
    return interruptedAtMs! / totalDurationMs;
  }
}
