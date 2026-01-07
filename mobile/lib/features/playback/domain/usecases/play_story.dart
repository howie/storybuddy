import '../entities/story_playback.dart';
import '../repositories/playback_repository.dart';

/// Use case for playing a story audio.
class PlayStoryUseCase {
  PlayStoryUseCase({required this.repository});

  final PlaybackRepository repository;

  /// Starts playing a story.
  Future<void> call(String storyId) async {
    if (storyId.isEmpty) {
      throw InvalidStoryIdException();
    }

    return repository.playStory(storyId);
  }

  /// Pauses current playback.
  Future<void> pause() async {
    return repository.pause();
  }

  /// Resumes paused playback.
  Future<void> resume() async {
    return repository.resume();
  }

  /// Toggles play/pause state.
  Future<void> toggle() async {
    // This would need to check current state
    // Implemented in the notifier instead
  }

  /// Seeks to a specific position.
  Future<void> seekTo(Duration position) async {
    return repository.seekTo(position);
  }

  /// Stops playback.
  Future<void> stop() async {
    return repository.stop();
  }

  /// Sets playback speed.
  Future<void> setSpeed(double speed) async {
    if (speed < 0.5 || speed > 2.0) {
      throw InvalidPlaybackSpeedException();
    }
    return repository.setSpeed(speed);
  }

  /// Returns the playback state stream.
  Stream<StoryPlayback> get playbackState => repository.playbackState;
}

/// Exception thrown when story ID is invalid.
class InvalidStoryIdException implements Exception {
  @override
  String toString() => '故事 ID 無效';
}

/// Exception thrown when playback speed is invalid.
class InvalidPlaybackSpeedException implements Exception {
  @override
  String toString() => '播放速度必須在 0.5 到 2.0 之間';
}

/// Exception thrown when no audio is available for the story.
class NoAudioAvailableException implements Exception {
  @override
  String toString() => '此故事沒有可播放的語音';
}
