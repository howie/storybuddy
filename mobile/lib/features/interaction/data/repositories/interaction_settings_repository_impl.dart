import 'package:dio/dio.dart';

import 'package:storybuddy/features/interaction/data/datasources/interaction_local_datasource.dart';
import 'package:storybuddy/features/interaction/data/models/interaction_settings_model.dart';
import 'package:storybuddy/features/interaction/domain/entities/interaction_settings.dart';
import 'package:storybuddy/features/interaction/domain/repositories/interaction_settings_repository.dart';

/// T066 [US3] Implement settings repository.
class InteractionSettingsRepositoryImpl
    implements InteractionSettingsRepository {
  InteractionSettingsRepositoryImpl({
    required Dio dio,
    required InteractionLocalDatasource localDatasource,
  })  : _dio = dio,
        _localDatasource = localDatasource;

  final Dio _dio;
  final InteractionLocalDatasource _localDatasource;

  @override
  Future<InteractionSettings> getSettings() async {
    try {
      final response = await _dio.get('/v1/interaction/settings');
      final model = InteractionSettingsModel.fromJson(
        response.data as Map<String, dynamic>,
      );

      // Cache settings
      await _localDatasource.cacheSettings(model);

      return InteractionSettings(
        recordingEnabled: model.recordingEnabled,
        autoTranscribe: model.autoTranscribe,
        retentionDays: model.retentionDays,
      );
    } on DioException {
      // Try to return cached settings on network error
      final cached = await _localDatasource.getCachedSettings();
      if (cached != null) {
        return InteractionSettings(
          recordingEnabled: cached.recordingEnabled,
          autoTranscribe: cached.autoTranscribe,
          retentionDays: cached.retentionDays,
        );
      }
      // Return defaults
      return const InteractionSettings();
    }
  }

  @override
  Future<bool> updateSettings(InteractionSettings settings) async {
    try {
      final response = await _dio.put(
        '/v1/interaction/settings',
        data: {
          'recordingEnabled': settings.recordingEnabled,
          'autoTranscribe': settings.autoTranscribe,
          'retentionDays': settings.retentionDays,
        },
      );

      final result = UpdateSettingsResponse.fromJson(
        response.data as Map<String, dynamic>,
      );

      if (result.success && result.settings != null) {
        await _localDatasource.cacheSettings(result.settings!);
      }

      return result.success;
    } on DioException {
      return false;
    }
  }

  @override
  Future<bool> updateRecordingEnabled(bool enabled) async {
    try {
      final response = await _dio.put(
        '/v1/interaction/settings',
        data: {'recordingEnabled': enabled},
      );

      final result = UpdateSettingsResponse.fromJson(
        response.data as Map<String, dynamic>,
      );

      if (result.success && result.settings != null) {
        await _localDatasource.cacheSettings(result.settings!);
      }

      return result.success;
    } on DioException {
      return false;
    }
  }

  @override
  Future<bool> updateRetentionDays(int days) async {
    try {
      final response = await _dio.put(
        '/v1/interaction/settings',
        data: {'retentionDays': days},
      );

      final result = UpdateSettingsResponse.fromJson(
        response.data as Map<String, dynamic>,
      );

      if (result.success && result.settings != null) {
        await _localDatasource.cacheSettings(result.settings!);
      }

      return result.success;
    } on DioException {
      return false;
    }
  }

  @override
  Future<StorageUsage> getStorageUsage({String? sessionId}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (sessionId != null) {
        queryParams['sessionId'] = sessionId;
      }

      final response = await _dio.get(
        '/v1/interaction/storage',
        queryParameters: queryParams,
      );

      final usage = StorageUsage.fromJson(
        response.data as Map<String, dynamic>,
      );

      await _localDatasource.cacheStorageUsage(usage);

      return usage;
    } on DioException {
      // Try cached
      final cached = await _localDatasource.getCachedStorageUsage();
      if (cached != null) return cached;

      // Return empty
      return const StorageUsage(
        totalRecordings: 0,
        totalSizeBytes: 0,
        totalSizeMB: 0,
        totalDurationMs: 0,
        totalDurationSeconds: 0,
      );
    }
  }

  @override
  Future<int> deleteSessionRecordings(String sessionId) async {
    try {
      final response = await _dio.delete(
        '/v1/interaction/recordings',
        queryParameters: {'sessionId': sessionId},
      );

      final data = response.data as Map<String, dynamic>;
      return data['deletedCount'] as int? ?? 0;
    } on DioException {
      return 0;
    }
  }
}
