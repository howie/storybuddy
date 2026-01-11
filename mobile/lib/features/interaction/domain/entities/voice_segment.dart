import 'package:freezed_annotation/freezed_annotation.dart';

part 'voice_segment.freezed.dart';
part 'voice_segment.g.dart';

/// Represents a segment of child speech during interaction.
///
/// A VoiceSegment captures a continuous period of speech from the child,
/// along with its transcription and optional audio recording.
@freezed
class VoiceSegment with _$VoiceSegment {
  const factory VoiceSegment({
    required String id,
    required String sessionId,
    required int sequence,
    required DateTime startedAt,
    required DateTime endedAt,
    String? transcript,
    String? audioUrl,
    @Default(false) bool isRecorded,
    @Default('opus') String audioFormat,
    required int durationMs,
    required DateTime createdAt,
  }) = _VoiceSegment;

  factory VoiceSegment.fromJson(Map<String, dynamic> json) =>
      _$VoiceSegmentFromJson(json);
}

/// Extension methods for VoiceSegment.
extension VoiceSegmentX on VoiceSegment {
  /// Whether this segment has been transcribed.
  bool get hasTranscript => transcript != null && transcript!.isNotEmpty;

  /// Whether this segment has an audio recording.
  bool get hasAudio => audioUrl != null && audioUrl!.isNotEmpty;

  /// Duration as a Duration object.
  Duration get duration => Duration(milliseconds: durationMs);
}
