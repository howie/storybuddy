import '../entities/voice_profile.dart';
import '../repositories/voice_profile_repository.dart';

/// Use case for uploading a voice profile to the server.
class UploadVoiceUseCase {
  UploadVoiceUseCase({required this.repository});

  final VoiceProfileRepository repository;

  /// Uploads a voice profile to the server for processing.
  Future<VoiceProfile> call(String profileId) async {
    // Get the profile first
    final profile = await repository.getVoiceProfile(profileId);
    if (profile == null) {
      throw VoiceProfileNotFoundException(profileId);
    }

    // Validate it's in a valid state for upload
    if (profile.localAudioPath == null) {
      throw NoRecordingToUploadException();
    }

    // Upload to server
    return repository.uploadVoiceProfile(profileId);
  }

  /// Refreshes the status of a voice profile from the server.
  Future<VoiceProfile> refreshStatus(String profileId) async {
    return repository.refreshStatus(profileId);
  }

  /// Returns a stream that watches the voice profile status.
  Stream<VoiceProfile?> watchStatus(String profileId) {
    return repository.watchVoiceProfile(profileId);
  }
}

/// Exception thrown when a voice profile is not found.
class VoiceProfileNotFoundException implements Exception {
  VoiceProfileNotFoundException(this.profileId);

  final String profileId;

  @override
  String toString() => '找不到語音檔案：$profileId';
}

/// Exception thrown when there's no recording to upload.
class NoRecordingToUploadException implements Exception {
  @override
  String toString() => '沒有可上傳的錄音';
}
