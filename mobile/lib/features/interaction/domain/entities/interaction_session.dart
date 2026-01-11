import 'package:freezed_annotation/freezed_annotation.dart';

part 'interaction_session.freezed.dart';
part 'interaction_session.g.dart';

/// Session mode for story playback.
enum SessionMode {
  interactive,
  passive,
}

/// Status of an interaction session.
enum SessionStatus {
  calibrating,
  active,
  paused,
  completed,
  error,
}

/// Represents a single interactive storytelling session.
///
/// An InteractionSession tracks the state and metadata of a story playback
/// where the child can interact with the AI through voice.
@freezed
class InteractionSession with _$InteractionSession {
  const factory InteractionSession({
    required String id,
    required String storyId,
    required String parentId,
    required DateTime startedAt,
    required DateTime createdAt, required DateTime updatedAt, DateTime? endedAt,
    @Default(SessionMode.interactive) SessionMode mode,
    @Default(SessionStatus.calibrating) SessionStatus status,
  }) = _InteractionSession;

  factory InteractionSession.fromJson(Map<String, dynamic> json) =>
      _$InteractionSessionFromJson(json);
}

/// Extension methods for InteractionSession.
extension InteractionSessionX on InteractionSession {
  /// Whether the session is currently active and accepting voice input.
  bool get isActive => status == SessionStatus.active;

  /// Whether the session has ended.
  bool get isEnded =>
      status == SessionStatus.completed || status == SessionStatus.error;

  /// Duration of the session in milliseconds.
  int? get durationMs {
    if (endedAt == null) return null;
    return endedAt!.difference(startedAt).inMilliseconds;
  }

  /// Whether this is an interactive session.
  bool get isInteractive => mode == SessionMode.interactive;
}
