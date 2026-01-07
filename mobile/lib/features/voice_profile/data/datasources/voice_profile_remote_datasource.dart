import 'dart:io';

import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../models/voice_profile_model.dart';

/// Remote data source for VoiceProfile operations.
abstract class VoiceProfileRemoteDataSource {
  /// Fetches all voice profiles for the current parent.
  Future<List<VoiceProfileModel>> getVoiceProfiles();

  /// Fetches a single voice profile by ID.
  Future<VoiceProfileModel> getVoiceProfile(String id);

  /// Creates a new voice profile with audio upload.
  Future<VoiceProfileModel> createVoiceProfile({
    required String name,
    required String audioFilePath,
    required int sampleDurationSeconds,
  });

  /// Uploads audio file for an existing profile.
  Future<VoiceProfileModel> uploadAudio({
    required String profileId,
    required String audioFilePath,
  });

  /// Refreshes the status of a voice profile.
  Future<VoiceProfileModel> getStatus(String id);

  /// Deletes a voice profile.
  Future<void> deleteVoiceProfile(String id);
}

/// Implementation of [VoiceProfileRemoteDataSource].
class VoiceProfileRemoteDataSourceImpl implements VoiceProfileRemoteDataSource {
  VoiceProfileRemoteDataSourceImpl({required this.apiClient});

  final ApiClient apiClient;

  @override
  Future<List<VoiceProfileModel>> getVoiceProfiles() async {
    final response = await apiClient.get<List<dynamic>>('/voice-profiles');
    if (response.data == null) return [];
    return response.data!
        .map((json) => VoiceProfileModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<VoiceProfileModel> getVoiceProfile(String id) async {
    final response = await apiClient.get<Map<String, dynamic>>(
      '/voice-profiles/$id',
    );
    if (response.data == null) {
      throw Exception('No response data from get voice profile');
    }
    return VoiceProfileModel.fromJson(response.data!);
  }

  @override
  Future<VoiceProfileModel> createVoiceProfile({
    required String name,
    required String audioFilePath,
    required int sampleDurationSeconds,
  }) async {
    final file = File(audioFilePath);
    final fileName = audioFilePath.split('/').last;

    final formData = FormData.fromMap({
      'name': name,
      'sample_duration_seconds': sampleDurationSeconds,
      'audio': await MultipartFile.fromFile(
        file.path,
        filename: fileName,
      ),
    });

    final response = await apiClient.post<Map<String, dynamic>>(
      '/voice-profiles',
      data: formData,
    );
    if (response.data == null) {
      throw Exception('No response data from create voice profile');
    }
    return VoiceProfileModel.fromJson(response.data!);
  }

  @override
  Future<VoiceProfileModel> uploadAudio({
    required String profileId,
    required String audioFilePath,
  }) async {
    final file = File(audioFilePath);
    final fileName = audioFilePath.split('/').last;

    final formData = FormData.fromMap({
      'audio': await MultipartFile.fromFile(
        file.path,
        filename: fileName,
      ),
    });

    final response = await apiClient.post<Map<String, dynamic>>(
      '/voice-profiles/$profileId/audio',
      data: formData,
    );
    if (response.data == null) {
      throw Exception('No response data from upload audio');
    }
    return VoiceProfileModel.fromJson(response.data!);
  }

  @override
  Future<VoiceProfileModel> getStatus(String id) async {
    final response = await apiClient.get<Map<String, dynamic>>(
      '/voice-profiles/$id/status',
    );
    if (response.data == null) {
      throw Exception('No response data from get status');
    }
    return VoiceProfileModel.fromJson(response.data!);
  }

  @override
  Future<void> deleteVoiceProfile(String id) async {
    await apiClient.delete<void>('/voice-profiles/$id');
  }
}
