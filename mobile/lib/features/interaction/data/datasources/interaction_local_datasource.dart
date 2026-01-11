import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:storybuddy/features/interaction/data/models/interaction_settings_model.dart';

/// T065 [US3] Implement settings local datasource.
/// Caches interaction settings locally for offline access.

abstract class InteractionLocalDatasource {
  /// Get cached settings.
  Future<InteractionSettingsModel?> getCachedSettings();

  /// Cache settings.
  Future<void> cacheSettings(InteractionSettingsModel settings);

  /// Clear cached settings.
  Future<void> clearCache();

  /// Get cached storage usage.
  Future<StorageUsage?> getCachedStorageUsage();

  /// Cache storage usage.
  Future<void> cacheStorageUsage(StorageUsage usage);
}

class InteractionLocalDatasourceImpl implements InteractionLocalDatasource {
  InteractionLocalDatasourceImpl({
    FlutterSecureStorage? secureStorage,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _secureStorage;

  static const _settingsKey = 'interaction_settings';
  static const _storageUsageKey = 'interaction_storage_usage';

  @override
  Future<InteractionSettingsModel?> getCachedSettings() async {
    try {
      final json = await _secureStorage.read(key: _settingsKey);
      if (json == null) return null;

      final data = jsonDecode(json) as Map<String, dynamic>;
      return InteractionSettingsModel.fromJson(data);
    } catch (e) {
      // Return null on parse error
      return null;
    }
  }

  @override
  Future<void> cacheSettings(InteractionSettingsModel settings) async {
    final json = jsonEncode(settings.toJson());
    await _secureStorage.write(key: _settingsKey, value: json);
  }

  @override
  Future<void> clearCache() async {
    await _secureStorage.delete(key: _settingsKey);
    await _secureStorage.delete(key: _storageUsageKey);
  }

  @override
  Future<StorageUsage?> getCachedStorageUsage() async {
    try {
      final json = await _secureStorage.read(key: _storageUsageKey);
      if (json == null) return null;

      final data = jsonDecode(json) as Map<String, dynamic>;
      return StorageUsage.fromJson(data);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> cacheStorageUsage(StorageUsage usage) async {
    final json = jsonEncode(usage.toJson());
    await _secureStorage.write(key: _storageUsageKey, value: json);
  }
}
