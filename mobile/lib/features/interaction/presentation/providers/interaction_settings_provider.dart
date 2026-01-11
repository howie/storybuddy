import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:storybuddy/features/interaction/data/datasources/interaction_local_datasource.dart';
import 'package:storybuddy/features/interaction/data/models/interaction_settings_model.dart';
import 'package:storybuddy/features/interaction/data/repositories/interaction_settings_repository_impl.dart';
import 'package:storybuddy/features/interaction/domain/entities/interaction_settings.dart';
import 'package:storybuddy/features/interaction/domain/repositories/interaction_settings_repository.dart';

/// T067 [US3] Implement interaction settings provider.

/// Provider for Dio HTTP client.
final dioProvider = Provider<Dio>((ref) {
  return Dio(
    BaseOptions(
      baseUrl: 'https://api.storybuddy.app', // Configure from environment
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );
});

/// Provider for local datasource.
final interactionLocalDatasourceProvider =
    Provider<InteractionLocalDatasource>((ref) {
  return InteractionLocalDatasourceImpl();
});

/// Provider for settings repository.
final interactionSettingsRepositoryProvider =
    Provider<InteractionSettingsRepository>((ref) {
  return InteractionSettingsRepositoryImpl(
    dio: ref.watch(dioProvider),
    localDatasource: ref.watch(interactionLocalDatasourceProvider),
  );
});

/// State notifier for interaction settings.
class InteractionSettingsNotifier
    extends StateNotifier<AsyncValue<InteractionSettings>> {
  InteractionSettingsNotifier(this._repository)
      : super(const AsyncValue.loading()) {
    _loadSettings();
  }

  final InteractionSettingsRepository _repository;

  Future<void> _loadSettings() async {
    state = const AsyncValue.loading();
    try {
      final settings = await _repository.getSettings();
      state = AsyncValue.data(settings);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Refresh settings from server.
  Future<void> refresh() => _loadSettings();

  /// Update recording enabled setting.
  Future<void> updateRecordingEnabled(bool enabled) async {
    final currentSettings = state.valueOrNull;
    if (currentSettings == null) return;

    // Optimistically update
    state = AsyncValue.data(
      currentSettings.copyWith(recordingEnabled: enabled),
    );

    final success = await _repository.updateRecordingEnabled(enabled);

    if (!success) {
      // Revert on failure
      state = AsyncValue.data(currentSettings);
    }
  }

  /// Update auto-transcribe setting.
  Future<void> updateAutoTranscribe(bool enabled) async {
    final currentSettings = state.valueOrNull;
    if (currentSettings == null) return;

    state = AsyncValue.data(
      currentSettings.copyWith(autoTranscribe: enabled),
    );

    final success = await _repository.updateSettings(
      currentSettings.copyWith(autoTranscribe: enabled),
    );

    if (!success) {
      state = AsyncValue.data(currentSettings);
    }
  }

  /// Update retention days setting.
  Future<void> updateRetentionDays(int days) async {
    final currentSettings = state.valueOrNull;
    if (currentSettings == null) return;

    state = AsyncValue.data(
      currentSettings.copyWith(retentionDays: days),
    );

    final success = await _repository.updateRetentionDays(days);

    if (!success) {
      state = AsyncValue.data(currentSettings);
    }
  }

  /// T084 [US4] Update email notifications setting.
  Future<void> updateEmailNotifications(bool enabled) async {
    final currentSettings = state.valueOrNull;
    if (currentSettings == null) return;

    state = AsyncValue.data(
      currentSettings.copyWith(emailNotifications: enabled),
    );

    final success = await _repository.updateSettings(
      currentSettings.copyWith(emailNotifications: enabled),
    );

    if (!success) {
      state = AsyncValue.data(currentSettings);
    }
  }

  /// T084 [US4] Update notification frequency setting.
  Future<void> updateNotificationFrequency(
      NotificationFrequency frequency,) async {
    final currentSettings = state.valueOrNull;
    if (currentSettings == null) return;

    state = AsyncValue.data(
      currentSettings.copyWith(notificationFrequency: frequency),
    );

    final success = await _repository.updateSettings(
      currentSettings.copyWith(notificationFrequency: frequency),
    );

    if (!success) {
      state = AsyncValue.data(currentSettings);
    }
  }

  /// T084 [US4] Update notification email.
  Future<void> updateNotificationEmail(String email) async {
    final currentSettings = state.valueOrNull;
    if (currentSettings == null) return;

    state = AsyncValue.data(
      currentSettings.copyWith(notificationEmail: email),
    );

    final success = await _repository.updateSettings(
      currentSettings.copyWith(notificationEmail: email),
    );

    if (!success) {
      state = AsyncValue.data(currentSettings);
    }
  }
}

/// Provider for interaction settings state.
final interactionSettingsProvider = StateNotifierProvider<
    InteractionSettingsNotifier, AsyncValue<InteractionSettings>>((ref) {
  return InteractionSettingsNotifier(
    ref.watch(interactionSettingsRepositoryProvider),
  );
});

/// Provider for storage usage.
final storageUsageProvider = FutureProvider<StorageUsage>((ref) async {
  final repository = ref.watch(interactionSettingsRepositoryProvider);
  return repository.getStorageUsage();
});
