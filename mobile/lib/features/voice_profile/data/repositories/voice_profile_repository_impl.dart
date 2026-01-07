import 'dart:io';

import 'package:uuid/uuid.dart';

import '../../../../core/database/enums.dart';
import '../../../../core/network/connectivity_service.dart';
import '../../domain/entities/voice_profile.dart';
import '../../domain/repositories/voice_profile_repository.dart';
import '../datasources/voice_profile_local_datasource.dart';
import '../datasources/voice_profile_remote_datasource.dart';

/// Implementation of [VoiceProfileRepository] with offline-first pattern.
class VoiceProfileRepositoryImpl implements VoiceProfileRepository {
  VoiceProfileRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.connectivityService,
  });

  final VoiceProfileRemoteDataSource remoteDataSource;
  final VoiceProfileLocalDataSource localDataSource;
  final ConnectivityService connectivityService;

  final _uuid = const Uuid();

  @override
  Future<List<VoiceProfile>> getVoiceProfiles() async {
    // Return local data immediately
    final localProfiles = await localDataSource.getVoiceProfiles();

    // Refresh from remote in background if online
    if (await connectivityService.isConnected) {
      _refreshProfilesFromRemote();
    }

    return localProfiles;
  }

  @override
  Future<VoiceProfile?> getVoiceProfile(String id) async {
    // Try local first
    final localProfile = await localDataSource.getVoiceProfile(id);

    if (localProfile != null) {
      return localProfile;
    }

    // Fetch from remote if not found locally and online
    if (await connectivityService.isConnected) {
      try {
        final remoteModel = await remoteDataSource.getVoiceProfile(id);
        final profile = remoteModel.toEntity();
        await localDataSource.saveVoiceProfile(profile);
        return profile;
      } catch (_) {
        return null;
      }
    }

    return null;
  }

  @override
  Future<VoiceProfile> createVoiceProfile({
    required String name,
    required String localAudioPath,
    required int sampleDurationSeconds,
  }) async {
    // Generate local ID
    final id = _uuid.v4();

    // Create profile entity with pending status
    final profile = VoiceProfile.fromRecording(
      id: id,
      parentId: '', // Will be set from auth context
      name: name,
      localAudioPath: localAudioPath,
      sampleDurationSeconds: sampleDurationSeconds,
    );

    // Save locally first (optimistic update)
    await localDataSource.saveVoiceProfile(profile);

    return profile;
  }

  @override
  Future<VoiceProfile> uploadVoiceProfile(String id) async {
    final profile = await localDataSource.getVoiceProfile(id);
    if (profile == null) {
      throw Exception('Voice profile not found');
    }

    if (profile.localAudioPath == null) {
      throw Exception('No audio file to upload');
    }

    // Verify file exists
    final file = File(profile.localAudioPath!);
    if (!await file.exists()) {
      throw Exception('Audio file not found');
    }

    if (!await connectivityService.isConnected) {
      throw Exception('需要網路連線才能上傳');
    }

    try {
      final remoteModel = await remoteDataSource.createVoiceProfile(
        name: profile.name,
        audioFilePath: profile.localAudioPath!,
        sampleDurationSeconds: profile.sampleDurationSeconds ?? 0,
      );

      final uploadedProfile = remoteModel.toEntity(
        localAudioPath: profile.localAudioPath,
      );
      await localDataSource.saveVoiceProfile(uploadedProfile);

      return uploadedProfile;
    } catch (e) {
      // Update status to indicate failure
      await localDataSource.updateStatus(
        id,
        VoiceProfileStatus.failed,
        errorMessage: e.toString(),
      );
      rethrow;
    }
  }

  @override
  Future<VoiceProfile> refreshStatus(String id) async {
    if (!await connectivityService.isConnected) {
      final local = await localDataSource.getVoiceProfile(id);
      if (local != null) return local;
      throw Exception('No network connection');
    }

    try {
      final remoteModel = await remoteDataSource.getStatus(id);
      final existing = await localDataSource.getVoiceProfile(id);

      final updated = remoteModel.toEntity(
        localAudioPath: existing?.localAudioPath,
      );
      await localDataSource.saveVoiceProfile(updated);

      return updated;
    } catch (e) {
      final local = await localDataSource.getVoiceProfile(id);
      if (local != null) return local;
      rethrow;
    }
  }

  @override
  Future<void> deleteVoiceProfile(String id) async {
    // Delete local audio file if exists
    final profile = await localDataSource.getVoiceProfile(id);
    if (profile?.localAudioPath != null) {
      try {
        final file = File(profile!.localAudioPath!);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {
        // Ignore file deletion errors
      }
    }

    // Delete from local database
    await localDataSource.deleteVoiceProfile(id);

    // Delete from remote if online
    if (await connectivityService.isConnected) {
      try {
        await remoteDataSource.deleteVoiceProfile(id);
      } catch (_) {
        // Ignore remote delete errors
      }
    }
  }

  @override
  Future<void> syncAllPending() async {
    if (!await connectivityService.isConnected) {
      return;
    }

    final pendingProfiles = await localDataSource.getPendingProfiles();
    for (final profile in pendingProfiles) {
      try {
        await uploadVoiceProfile(profile.id);
      } catch (_) {
        // Continue with other profiles
      }
    }
  }

  @override
  Stream<List<VoiceProfile>> watchVoiceProfiles() {
    return localDataSource.watchVoiceProfiles();
  }

  @override
  Stream<VoiceProfile?> watchVoiceProfile(String id) {
    return localDataSource.watchVoiceProfile(id);
  }

  /// Refreshes profiles from remote in background.
  Future<void> _refreshProfilesFromRemote() async {
    try {
      final remoteModels = await remoteDataSource.getVoiceProfiles();

      for (final model in remoteModels) {
        final existing = await localDataSource.getVoiceProfile(model.id);
        final profile = model.toEntity(
          localAudioPath: existing?.localAudioPath,
        );
        await localDataSource.saveVoiceProfile(profile);
      }
    } catch (_) {
      // Ignore refresh errors
    }
  }
}
