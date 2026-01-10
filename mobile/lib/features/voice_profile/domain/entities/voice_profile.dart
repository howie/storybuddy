import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/database/enums.dart';

part 'voice_profile.freezed.dart';

/// VoiceProfile entity representing a parent's voice clone profile.
@freezed
class VoiceProfile with _$VoiceProfile {
  const factory VoiceProfile({
    /// Unique identifier.
    required String id,

    /// Parent/owner ID.
    required String parentId,

    /// Profile name (e.g., "Dad's Voice", "Mom's Voice").
    required String name,

    /// Voice cloning status.
    required VoiceProfileStatus status,

    /// Creation timestamp.
    required DateTime createdAt, /// Last update timestamp.
    required DateTime updatedAt, /// Duration of the voice sample in seconds.
    int? sampleDurationSeconds,

    /// Local path to the recorded audio file.
    String? localAudioPath,

    /// Remote URL of the processed voice model.
    String? remoteVoiceModelUrl,

    /// Error message if cloning failed.
    String? errorMessage,

    /// Sync status for offline support.
    @Default(SyncStatus.synced) SyncStatus syncStatus,
  }) = _VoiceProfile;

  const VoiceProfile._();

  /// Creates a new voice profile from a recording.
  factory VoiceProfile.fromRecording({
    required String id,
    required String parentId,
    required String name,
    required String localAudioPath,
    required int sampleDurationSeconds,
  }) {
    final now = DateTime.now();
    return VoiceProfile(
      id: id,
      parentId: parentId,
      name: name,
      status: VoiceProfileStatus.pending,
      sampleDurationSeconds: sampleDurationSeconds,
      localAudioPath: localAudioPath,
      createdAt: now,
      updatedAt: now,
      syncStatus: SyncStatus.pendingSync,
    );
  }

  /// Returns true if the voice profile is ready to use.
  bool get isReady => status == VoiceProfileStatus.ready;

  /// Returns true if the voice profile is currently being processed.
  bool get isProcessing => status == VoiceProfileStatus.processing;

  /// Returns true if the voice cloning failed.
  bool get hasFailed => status == VoiceProfileStatus.failed;

  /// Returns true if the profile has pending local changes.
  bool get hasPendingChanges => syncStatus == SyncStatus.pendingSync;

  /// Returns a display-friendly status label.
  String get statusLabel => switch (status) {
        VoiceProfileStatus.pending => '等待上傳',
        VoiceProfileStatus.processing => '處理中',
        VoiceProfileStatus.ready => '已就緒',
        VoiceProfileStatus.failed => '失敗',
      };

  /// Returns the minimum required recording duration in seconds.
  static const int minDurationSeconds = 30;

  /// Returns the maximum allowed recording duration in seconds.
  static const int maxDurationSeconds = 60;

  /// Returns true if the sample duration is valid.
  bool get hasValidDuration {
    if (sampleDurationSeconds == null) return false;
    return sampleDurationSeconds! >= minDurationSeconds &&
        sampleDurationSeconds! <= maxDurationSeconds;
  }
}
