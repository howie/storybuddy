import '../entities/story_playback.dart';

/// Repository interface for audio playback operations.
abstract class PlaybackRepository {
  /// Generates audio for a story using AI voice cloning.
  /// Requires network connection and a ready voice profile.
  Future<String> generateAudio({
    required String storyId,
    required String voiceProfileId,
  });

  /// Starts playing a story.
  /// Uses cached audio if available, otherwise streams from remote.
  Future<void> playStory(String storyId);

  /// Pauses current playback.
  Future<void> pause();

  /// Resumes paused playback.
  Future<void> resume();

  /// Seeks to a specific position.
  Future<void> seekTo(Duration position);

  /// Stops playback completely.
  Future<void> stop();

  /// Sets playback speed (0.5 to 2.0).
  Future<void> setSpeed(double speed);

  /// Downloads audio for offline playback.
  Future<void> downloadAudio(String storyId);

  /// Cancels ongoing audio download.
  Future<void> cancelDownload(String storyId);

  /// Gets the current playback state stream.
  Stream<StoryPlayback> get playbackState;

  /// Gets the download progress stream.
  Stream<AudioDownloadProgress> watchDownloadProgress(String storyId);

  /// Returns the currently playing story ID, if any.
  String? get currentStoryId;

  /// Disposes of resources.
  Future<void> dispose();
}
