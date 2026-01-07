import '../repositories/playback_repository.dart';

/// Use case for generating audio for a story using AI voice cloning.
class GenerateAudioUseCase {
  GenerateAudioUseCase({required this.repository});

  final PlaybackRepository repository;

  /// Generates audio for a story using the specified voice profile.
  ///
  /// Returns the URL of the generated audio.
  Future<String> call({
    required String storyId,
    required String voiceProfileId,
  }) async {
    // Validate inputs
    if (storyId.isEmpty) {
      throw InvalidStoryIdException();
    }

    if (voiceProfileId.isEmpty) {
      throw InvalidVoiceProfileIdException();
    }

    return repository.generateAudio(
      storyId: storyId,
      voiceProfileId: voiceProfileId,
    );
  }
}

/// Exception thrown when story ID is invalid.
class InvalidStoryIdException implements Exception {
  @override
  String toString() => '故事 ID 無效';
}

/// Exception thrown when voice profile ID is invalid.
class InvalidVoiceProfileIdException implements Exception {
  @override
  String toString() => '語音 ID 無效';
}

/// Exception thrown when voice profile is not ready.
class VoiceProfileNotReadyException implements Exception {
  @override
  String toString() => '語音檔案尚未準備就緒';
}

/// Exception thrown when audio generation fails.
class AudioGenerationException implements Exception {
  AudioGenerationException(this.message);

  final String message;

  @override
  String toString() => '語音生成失敗：$message';
}
