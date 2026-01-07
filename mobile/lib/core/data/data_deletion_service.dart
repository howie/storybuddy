import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../shared/providers/database_provider.dart';
import '../database/database.dart';
import '../storage/secure_storage_service.dart';

part 'data_deletion_service.g.dart';

/// Service for deleting local data.
class DataDeletionService {
  DataDeletionService({
    required this.database,
    required this.secureStorage,
  });

  final AppDatabase database;
  final SecureStorageService secureStorage;

  /// Deletes all local data except authentication.
  Future<DataDeletionResult> deleteAllLocalData() async {
    final errors = <String>[];
    int filesDeleted = 0;
    int recordsDeleted = 0;

    // Delete cached audio files
    try {
      final audioResult = await _deleteCachedAudioFiles();
      filesDeleted += audioResult;
    } catch (e) {
      errors.add('Failed to delete audio files: $e');
      debugPrint('Error deleting audio files: $e');
    }

    // Delete database records
    try {
      final dbResult = await _clearDatabaseTables();
      recordsDeleted += dbResult;
    } catch (e) {
      errors.add('Failed to clear database: $e');
      debugPrint('Error clearing database: $e');
    }

    // Clear encryption keys for audio (but keep auth)
    try {
      await _clearStorageKeys();
    } catch (e) {
      errors.add('Failed to clear storage keys: $e');
      debugPrint('Error clearing storage keys: $e');
    }

    return DataDeletionResult(
      success: errors.isEmpty,
      filesDeleted: filesDeleted,
      recordsDeleted: recordsDeleted,
      errors: errors,
    );
  }

  Future<int> _deleteCachedAudioFiles() async {
    int count = 0;

    // Delete voice recordings
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final recordingsDir = Directory('${appDir.path}/recordings');
      if (await recordingsDir.exists()) {
        final files = await recordingsDir.list().toList();
        for (final file in files) {
          if (file is File) {
            await file.delete();
            count++;
          }
        }
      }
    } catch (e) {
      debugPrint('Error deleting recordings: $e');
    }

    // Delete cached story audio
    try {
      final cacheDir = await getTemporaryDirectory();
      final audioDir = Directory('${cacheDir.path}/audio');
      if (await audioDir.exists()) {
        final files = await audioDir.list().toList();
        for (final file in files) {
          if (file is File) {
            await file.delete();
            count++;
          }
        }
      }
    } catch (e) {
      debugPrint('Error deleting cached audio: $e');
    }

    return count;
  }

  Future<int> _clearDatabaseTables() async {
    var count = 0;

    // Clear stories
    count += await database.delete(database.stories).go();

    // Clear voice profiles
    count += await database.delete(database.voiceProfiles).go();

    // Clear Q&A sessions
    count += await database.delete(database.qASessions).go();

    // Clear Q&A messages
    count += await database.delete(database.qAMessages).go();

    // Clear pending questions
    count += await database.delete(database.pendingQuestions).go();

    // Clear sync operations
    count += await database.delete(database.syncOperations).go();

    return count;
  }

  Future<void> _clearStorageKeys() async {
    // Clear audio encryption keys but keep auth tokens
    await secureStorage.clearAll();
  }
}

/// Result of a data deletion operation.
class DataDeletionResult {
  const DataDeletionResult({
    required this.success,
    this.filesDeleted = 0,
    this.recordsDeleted = 0,
    this.errors = const [],
  });

  final bool success;
  final int filesDeleted;
  final int recordsDeleted;
  final List<String> errors;

  int get totalDeleted => filesDeleted + recordsDeleted;
}

/// Provider for DataDeletionService.
@riverpod
DataDeletionService dataDeletionService(Ref ref) {
  final database = ref.watch(databaseProvider);
  final secureStorage = ref.watch(secureStorageServiceProvider);

  return DataDeletionService(
    database: database,
    secureStorage: secureStorage,
  );
}
