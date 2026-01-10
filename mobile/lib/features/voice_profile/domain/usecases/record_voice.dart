import '../entities/voice_profile.dart';
import '../repositories/voice_profile_repository.dart';

/// Use case for recording a voice sample.
class RecordVoiceUseCase {
  RecordVoiceUseCase({required this.repository});

  final VoiceProfileRepository repository;

  /// Minimum recording duration in seconds.
  static const int minDurationSeconds = VoiceProfile.minDurationSeconds;

  /// Maximum recording duration in seconds.
  static const int maxDurationSeconds = VoiceProfile.maxDurationSeconds;

  /// Creates a voice profile from a recorded audio file.
  Future<VoiceProfile> call({
    required String name,
    required String localAudioPath,
    required int sampleDurationSeconds,
  }) async {
    // Validate duration
    if (sampleDurationSeconds < minDurationSeconds) {
      throw RecordingTooShortException(
        minDuration: minDurationSeconds,
        actualDuration: sampleDurationSeconds,
      );
    }

    if (sampleDurationSeconds > maxDurationSeconds) {
      throw RecordingTooLongException(
        maxDuration: maxDurationSeconds,
        actualDuration: sampleDurationSeconds,
      );
    }

    return repository.createVoiceProfile(
      name: name,
      localAudioPath: localAudioPath,
      sampleDurationSeconds: sampleDurationSeconds,
    );
  }
}

/// Exception thrown when recording is too short.
class RecordingTooShortException implements Exception {
  RecordingTooShortException({
    required this.minDuration,
    required this.actualDuration,
  });

  final int minDuration;
  final int actualDuration;

  @override
  String toString() => '錄音時間太短：至少需要 $minDuration 秒，目前只有 $actualDuration 秒';
}

/// Exception thrown when recording is too long.
class RecordingTooLongException implements Exception {
  RecordingTooLongException({
    required this.maxDuration,
    required this.actualDuration,
  });

  final int maxDuration;
  final int actualDuration;

  @override
  String toString() => '錄音時間太長：最多 $maxDuration 秒，目前有 $actualDuration 秒';
}
