import 'package:storybuddy/features/interaction/data/models/interaction_settings_model.dart';
import 'package:storybuddy/features/interaction/domain/entities/interaction_settings.dart';

/// Repository interface for interaction settings.
abstract class InteractionSettingsRepository {
  /// Get current settings.
  Future<InteractionSettings> getSettings();

  /// Update settings.
  Future<bool> updateSettings(InteractionSettings settings);

  /// Update recording enabled setting.
  Future<bool> updateRecordingEnabled(bool enabled);

  /// Update retention days setting.
  Future<bool> updateRetentionDays(int days);

  /// Get storage usage.
  Future<StorageUsage> getStorageUsage({String? sessionId});

  /// Delete all recordings for a session.
  Future<int> deleteSessionRecordings(String sessionId);
}
