import '../entities/voice_profile.dart';

/// Repository interface for VoiceProfile operations.
abstract class VoiceProfileRepository {
  /// Gets all voice profiles for the current parent.
  Future<List<VoiceProfile>> getVoiceProfiles();

  /// Gets a voice profile by ID.
  Future<VoiceProfile?> getVoiceProfile(String id);

  /// Creates a new voice profile from a recording.
  Future<VoiceProfile> createVoiceProfile({
    required String name,
    required String localAudioPath,
    required int sampleDurationSeconds,
  });

  /// Uploads a pending voice profile to the server.
  Future<VoiceProfile> uploadVoiceProfile(
    String id, {
    void Function(int, int)? onSendProgress,
  });

  /// Updates voice profile status from the server.
  Future<VoiceProfile> refreshStatus(String id);

  /// Deletes a voice profile.
  Future<void> deleteVoiceProfile(String id);

  /// Syncs pending voice profiles with the server.
  Future<void> syncAllPending();

  /// Stream of voice profiles for reactive UI updates.
  Stream<List<VoiceProfile>> watchVoiceProfiles();

  /// Stream of a single voice profile for reactive UI updates.
  Stream<VoiceProfile?> watchVoiceProfile(String id);
}
