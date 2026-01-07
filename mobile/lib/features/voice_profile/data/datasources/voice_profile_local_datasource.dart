import 'package:drift/drift.dart';

import '../../../../core/database/database.dart';
import '../../../../core/database/enums.dart';
import '../../domain/entities/voice_profile.dart' as entity;

/// Local data source for VoiceProfile operations using Drift.
abstract class VoiceProfileLocalDataSource {
  /// Gets all voice profiles for the current parent.
  Future<List<entity.VoiceProfile>> getVoiceProfiles();

  /// Gets a single voice profile by ID.
  Future<entity.VoiceProfile?> getVoiceProfile(String id);

  /// Saves a voice profile to local database.
  Future<void> saveVoiceProfile(entity.VoiceProfile profile);

  /// Saves multiple voice profiles to local database.
  Future<void> saveVoiceProfiles(List<entity.VoiceProfile> profiles);

  /// Updates a voice profile in local database.
  Future<void> updateVoiceProfile(entity.VoiceProfile profile);

  /// Deletes a voice profile from local database.
  Future<void> deleteVoiceProfile(String id);

  /// Gets voice profiles with pending sync status.
  Future<List<entity.VoiceProfile>> getPendingProfiles();

  /// Updates sync status for a voice profile.
  Future<void> updateSyncStatus(String id, SyncStatus status);

  /// Updates status from server response.
  Future<void> updateStatus(String id, VoiceProfileStatus status, {String? errorMessage});

  /// Watches all voice profiles for reactive updates.
  Stream<List<entity.VoiceProfile>> watchVoiceProfiles();

  /// Watches a single voice profile for reactive updates.
  Stream<entity.VoiceProfile?> watchVoiceProfile(String id);
}

/// Implementation of [VoiceProfileLocalDataSource] using Drift.
class VoiceProfileLocalDataSourceImpl implements VoiceProfileLocalDataSource {
  VoiceProfileLocalDataSourceImpl({required this.database});

  final AppDatabase database;

  @override
  Future<List<entity.VoiceProfile>> getVoiceProfiles() async {
    final rows = await database.select(database.voiceProfiles).get();
    return rows.map<entity.VoiceProfile>(_voiceProfileFromRow).toList();
  }

  @override
  Future<entity.VoiceProfile?> getVoiceProfile(String id) async {
    final row = await (database.select(database.voiceProfiles)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row != null ? _voiceProfileFromRow(row) : null;
  }

  @override
  Future<void> saveVoiceProfile(entity.VoiceProfile profile) async {
    await database.into(database.voiceProfiles).insertOnConflictUpdate(
          _voiceProfileToCompanion(profile),
        );
  }

  @override
  Future<void> saveVoiceProfiles(List<entity.VoiceProfile> profiles) async {
    await database.batch((batch) {
      for (final profile in profiles) {
        batch.insert(
          database.voiceProfiles,
          _voiceProfileToCompanion(profile),
          onConflict: DoUpdate((_) => _voiceProfileToCompanion(profile)),
        );
      }
    });
  }

  @override
  Future<void> updateVoiceProfile(entity.VoiceProfile profile) async {
    await (database.update(database.voiceProfiles)
          ..where((t) => t.id.equals(profile.id)))
        .write(_voiceProfileToCompanion(profile));
  }

  @override
  Future<void> deleteVoiceProfile(String id) async {
    await (database.delete(database.voiceProfiles)
          ..where((t) => t.id.equals(id)))
        .go();
  }

  @override
  Future<List<entity.VoiceProfile>> getPendingProfiles() async {
    final rows = await (database.select(database.voiceProfiles)
          ..where(
            (t) => t.syncStatus.equalsValue(SyncStatus.pendingSync),
          ))
        .get();
    return rows.map<entity.VoiceProfile>(_voiceProfileFromRow).toList();
  }

  @override
  Future<void> updateSyncStatus(String id, SyncStatus status) async {
    await (database.update(database.voiceProfiles)
          ..where((t) => t.id.equals(id)))
        .write(VoiceProfilesCompanion(syncStatus: Value(status)));
  }

  @override
  Future<void> updateStatus(
    String id,
    VoiceProfileStatus status, {
    String? errorMessage,
  }) async {
    await (database.update(database.voiceProfiles)
          ..where((t) => t.id.equals(id)))
        .write(
      VoiceProfilesCompanion(
        status: Value(status),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Stream<List<entity.VoiceProfile>> watchVoiceProfiles() {
    return database.select(database.voiceProfiles).watch().map(
          (rows) => rows.map<entity.VoiceProfile>(_voiceProfileFromRow).toList(),
        );
  }

  @override
  Stream<entity.VoiceProfile?> watchVoiceProfile(String id) {
    return (database.select(database.voiceProfiles)
          ..where((t) => t.id.equals(id)))
        .watchSingleOrNull()
        .map((row) => row != null ? _voiceProfileFromRow(row) : null);
  }

  /// Converts a database row to a VoiceProfile entity.
  entity.VoiceProfile _voiceProfileFromRow(VoiceProfile row) {
    return entity.VoiceProfile(
      id: row.id,
      parentId: row.parentId,
      name: row.name,
      status: row.status,
      sampleDurationSeconds: row.sampleDurationSeconds,
      localAudioPath: row.localAudioPath,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      syncStatus: row.syncStatus,
    );
  }

  /// Converts a VoiceProfile entity to a database companion.
  VoiceProfilesCompanion _voiceProfileToCompanion(entity.VoiceProfile profile) {
    return VoiceProfilesCompanion(
      id: Value(profile.id),
      parentId: Value(profile.parentId),
      name: Value(profile.name),
      status: Value(profile.status),
      sampleDurationSeconds: Value(profile.sampleDurationSeconds),
      localAudioPath: Value(profile.localAudioPath),
      createdAt: Value(profile.createdAt),
      updatedAt: Value(profile.updatedAt),
      syncStatus: Value(profile.syncStatus),
    );
  }
}
