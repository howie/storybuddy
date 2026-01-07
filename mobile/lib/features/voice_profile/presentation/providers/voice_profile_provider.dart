import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/connectivity_service.dart';
import '../../../../shared/providers/database_provider.dart';
import '../../data/datasources/voice_profile_local_datasource.dart';
import '../../data/datasources/voice_profile_remote_datasource.dart';
import '../../data/repositories/voice_profile_repository_impl.dart';
import '../../data/services/audio_recording_service.dart';
import '../../domain/entities/voice_profile.dart';
import '../../domain/repositories/voice_profile_repository.dart';
import '../../domain/usecases/record_voice.dart';
import '../../domain/usecases/upload_voice.dart';

part 'voice_profile_provider.g.dart';

/// Provider for [AudioRecordingService].
@riverpod
AudioRecordingService audioRecordingService(AudioRecordingServiceRef ref) {
  final service = AudioRecordingService();
  ref.onDispose(() => service.dispose());
  return service;
}

/// Provider for [VoiceProfileRemoteDataSource].
@riverpod
VoiceProfileRemoteDataSource voiceProfileRemoteDataSource(
  VoiceProfileRemoteDataSourceRef ref,
) {
  final apiClient = ref.watch(apiClientProvider);
  return VoiceProfileRemoteDataSourceImpl(apiClient: apiClient);
}

/// Provider for [VoiceProfileLocalDataSource].
@riverpod
VoiceProfileLocalDataSource voiceProfileLocalDataSource(
  VoiceProfileLocalDataSourceRef ref,
) {
  final database = ref.watch(databaseProvider);
  return VoiceProfileLocalDataSourceImpl(database: database);
}

/// Provider for [VoiceProfileRepository].
@riverpod
VoiceProfileRepository voiceProfileRepository(VoiceProfileRepositoryRef ref) {
  return VoiceProfileRepositoryImpl(
    remoteDataSource: ref.watch(voiceProfileRemoteDataSourceProvider),
    localDataSource: ref.watch(voiceProfileLocalDataSourceProvider),
    connectivityService: ref.watch(connectivityServiceProvider),
  );
}

/// Provider for [RecordVoiceUseCase].
@riverpod
RecordVoiceUseCase recordVoiceUseCase(RecordVoiceUseCaseRef ref) {
  return RecordVoiceUseCase(
    repository: ref.watch(voiceProfileRepositoryProvider),
  );
}

/// Provider for [UploadVoiceUseCase].
@riverpod
UploadVoiceUseCase uploadVoiceUseCase(UploadVoiceUseCaseRef ref) {
  return UploadVoiceUseCase(
    repository: ref.watch(voiceProfileRepositoryProvider),
  );
}

/// Provider for watching all voice profiles.
@riverpod
Stream<List<VoiceProfile>> voiceProfilesStream(VoiceProfilesStreamRef ref) {
  final repository = ref.watch(voiceProfileRepositoryProvider);
  return repository.watchVoiceProfiles();
}

/// Provider for watching a single voice profile.
@riverpod
Stream<VoiceProfile?> voiceProfileStream(
  VoiceProfileStreamRef ref,
  String id,
) {
  final repository = ref.watch(voiceProfileRepositoryProvider);
  return repository.watchVoiceProfile(id);
}

/// Notifier for voice profile list state and actions.
@riverpod
class VoiceProfileListNotifier extends _$VoiceProfileListNotifier {
  @override
  Future<List<VoiceProfile>> build() async {
    final repository = ref.watch(voiceProfileRepositoryProvider);
    return repository.getVoiceProfiles();
  }

  /// Refreshes the profile list from remote.
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(voiceProfileRepositoryProvider);
      return repository.getVoiceProfiles();
    });
  }

  /// Deletes a voice profile.
  Future<void> deleteProfile(String id) async {
    final repository = ref.read(voiceProfileRepositoryProvider);
    await repository.deleteVoiceProfile(id);
    ref.invalidateSelf();
  }
}

/// Recording state for the voice recording page.
enum RecordingState {
  initial,
  recording,
  paused,
  stopped,
  uploading,
  uploaded,
  error,
}

/// State for voice recording.
class VoiceRecordingState {
  const VoiceRecordingState({
    this.state = RecordingState.initial,
    this.elapsedSeconds = 0,
    this.recordingPath,
    this.uploadedProfileId,
    this.errorMessage,
  });

  final RecordingState state;
  final int elapsedSeconds;
  final String? recordingPath;
  final String? uploadedProfileId;
  final String? errorMessage;

  VoiceRecordingState copyWith({
    RecordingState? state,
    int? elapsedSeconds,
    String? recordingPath,
    String? uploadedProfileId,
    String? errorMessage,
  }) {
    return VoiceRecordingState(
      state: state ?? this.state,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      recordingPath: recordingPath ?? this.recordingPath,
      uploadedProfileId: uploadedProfileId ?? this.uploadedProfileId,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Notifier for voice recording state.
@riverpod
class VoiceRecordingNotifier extends _$VoiceRecordingNotifier {
  @override
  VoiceRecordingState build() {
    return const VoiceRecordingState();
  }

  /// Starts recording.
  Future<void> startRecording() async {
    try {
      final service = ref.read(audioRecordingServiceProvider);
      final path = await service.startRecording();

      state = state.copyWith(
        state: RecordingState.recording,
        recordingPath: path,
        elapsedSeconds: 0,
      );
    } catch (e) {
      state = state.copyWith(
        state: RecordingState.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Stops recording.
  Future<void> stopRecording() async {
    try {
      final service = ref.read(audioRecordingServiceProvider);
      final result = await service.stopRecording();

      state = state.copyWith(
        state: RecordingState.stopped,
        recordingPath: result.path,
        elapsedSeconds: result.durationSeconds,
      );
    } catch (e) {
      state = state.copyWith(
        state: RecordingState.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Cancels recording.
  Future<void> cancelRecording() async {
    final service = ref.read(audioRecordingServiceProvider);
    await service.cancelRecording();
    state = const VoiceRecordingState();
  }

  /// Updates elapsed time.
  void updateElapsedTime(int seconds) {
    state = state.copyWith(elapsedSeconds: seconds);
  }

  /// Uploads the recording.
  Future<void> uploadRecording({required String name}) async {
    if (state.recordingPath == null) {
      state = state.copyWith(
        state: RecordingState.error,
        errorMessage: '沒有錄音可上傳',
      );
      return;
    }

    state = state.copyWith(state: RecordingState.uploading);

    try {
      final recordUseCase = ref.read(recordVoiceUseCaseProvider);
      final uploadUseCase = ref.read(uploadVoiceUseCaseProvider);

      // Create local profile
      final profile = await recordUseCase.call(
        name: name,
        localAudioPath: state.recordingPath!,
        sampleDurationSeconds: state.elapsedSeconds,
      );

      // Upload to server
      await uploadUseCase.call(profile.id);

      state = state.copyWith(
        state: RecordingState.uploaded,
        uploadedProfileId: profile.id,
      );

      // Refresh list
      ref.invalidate(voiceProfileListNotifierProvider);
    } catch (e) {
      state = state.copyWith(
        state: RecordingState.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Resets the recording state.
  void reset() {
    state = const VoiceRecordingState();
  }
}
