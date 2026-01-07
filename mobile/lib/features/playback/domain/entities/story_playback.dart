import 'package:freezed_annotation/freezed_annotation.dart';

part 'story_playback.freezed.dart';

/// State of audio playback.
enum PlaybackState {
  /// Initial state, nothing playing.
  idle,

  /// Loading/buffering audio.
  loading,

  /// Audio is playing.
  playing,

  /// Audio is paused.
  paused,

  /// Playback completed.
  completed,

  /// Error occurred.
  error,
}

/// StoryPlayback entity representing the current playback state.
@freezed
class StoryPlayback with _$StoryPlayback {
  const factory StoryPlayback({
    /// Story ID being played.
    required String storyId,

    /// Story title.
    required String storyTitle,

    /// Current playback state.
    @Default(PlaybackState.idle) PlaybackState state,

    /// Current playback position.
    @Default(Duration.zero) Duration position,

    /// Total duration of the audio.
    @Default(Duration.zero) Duration duration,

    /// Buffered duration.
    @Default(Duration.zero) Duration bufferedPosition,

    /// Playback speed.
    @Default(1.0) double speed,

    /// Whether playing from local cache.
    @Default(false) bool isOffline,

    /// Error message if state is error.
    String? errorMessage,
  }) = _StoryPlayback;

  const StoryPlayback._();

  /// Returns the progress as a value between 0.0 and 1.0.
  double get progress {
    if (duration.inMilliseconds == 0) return 0.0;
    return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }

  /// Returns the buffered progress as a value between 0.0 and 1.0.
  double get bufferedProgress {
    if (duration.inMilliseconds == 0) return 0.0;
    return (bufferedPosition.inMilliseconds / duration.inMilliseconds)
        .clamp(0.0, 1.0);
  }

  /// Returns true if audio is currently playing.
  bool get isPlaying => state == PlaybackState.playing;

  /// Returns true if audio is paused.
  bool get isPaused => state == PlaybackState.paused;

  /// Returns true if playback has completed.
  bool get isCompleted => state == PlaybackState.completed;

  /// Returns true if there was an error.
  bool get hasError => state == PlaybackState.error;

  /// Returns true if audio is loading.
  bool get isLoading => state == PlaybackState.loading;

  /// Returns the remaining time.
  Duration get remainingTime => duration - position;

  /// Formats a duration as mm:ss.
  static String formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Returns the position formatted as mm:ss.
  String get formattedPosition => formatDuration(position);

  /// Returns the duration formatted as mm:ss.
  String get formattedDuration => formatDuration(duration);

  /// Returns the remaining time formatted as mm:ss.
  String get formattedRemainingTime => formatDuration(remainingTime);
}

/// Download progress for audio files.
@freezed
class AudioDownloadProgress with _$AudioDownloadProgress {
  const factory AudioDownloadProgress({
    /// Story ID.
    required String storyId,

    /// Download progress between 0.0 and 1.0.
    @Default(0.0) double progress,

    /// Whether download is complete.
    @Default(false) bool isComplete,

    /// Error message if download failed.
    String? errorMessage,
  }) = _AudioDownloadProgress;
}
