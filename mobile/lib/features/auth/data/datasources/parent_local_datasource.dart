import 'package:drift/drift.dart';

import '../../../../core/database/database.dart';
import '../../../../core/database/enums.dart';
import '../../../../core/errors/exceptions.dart';
import '../../domain/entities/parent.dart' as entity;

/// Local data source for Parent operations using Drift.
abstract class ParentLocalDataSource {
  /// Gets a parent by ID from local storage.
  Future<entity.Parent?> getParent(String id);

  /// Saves a parent to local storage.
  Future<void> saveParent(entity.Parent parent);

  /// Updates a parent in local storage.
  Future<void> updateParent(entity.Parent parent);

  /// Deletes a parent from local storage.
  Future<void> deleteParent(String id);

  /// Gets all parents with pending sync status.
  Future<List<entity.Parent>> getPendingSyncParents();

  /// Updates the sync status of a parent.
  Future<void> updateSyncStatus(String id, SyncStatus status);
}

/// Implementation of [ParentLocalDataSource] using Drift.
class ParentLocalDataSourceImpl implements ParentLocalDataSource {
  ParentLocalDataSourceImpl({required this.database});

  final AppDatabase database;

  @override
  Future<entity.Parent?> getParent(String id) async {
    try {
      final query = database.select(database.parents)
        ..where((t) => t.id.equals(id));
      final result = await query.getSingleOrNull();

      if (result == null) return null;

      return _mapToEntity(result);
    } catch (e) {
      throw CacheException(
        message: 'Failed to get parent from local storage: $e',
      );
    }
  }

  @override
  Future<void> saveParent(entity.Parent parent) async {
    try {
      await database.into(database.parents).insert(
            ParentsCompanion.insert(
              id: parent.id,
              name: parent.name,
              email: Value(parent.email),
              createdAt: parent.createdAt,
              updatedAt: parent.updatedAt,
              syncStatus: parent.syncStatus,
            ),
            mode: InsertMode.insertOrReplace,
          );
    } catch (e) {
      throw CacheException(
        message: 'Failed to save parent to local storage: $e',
      );
    }
  }

  @override
  Future<void> updateParent(entity.Parent parent) async {
    try {
      await (database.update(database.parents)
            ..where((t) => t.id.equals(parent.id)))
          .write(
        ParentsCompanion(
          name: Value(parent.name),
          email: Value(parent.email),
          updatedAt: Value(parent.updatedAt),
          syncStatus: Value(parent.syncStatus),
        ),
      );
    } catch (e) {
      throw CacheException(
        message: 'Failed to update parent in local storage: $e',
      );
    }
  }

  @override
  Future<void> deleteParent(String id) async {
    try {
      await (database.delete(database.parents)..where((t) => t.id.equals(id)))
          .go();
    } catch (e) {
      throw CacheException(
        message: 'Failed to delete parent from local storage: $e',
      );
    }
  }

  @override
  Future<List<entity.Parent>> getPendingSyncParents() async {
    try {
      final query = database.select(database.parents)
        ..where((t) => t.syncStatus.equalsValue(SyncStatus.pendingSync));
      final results = await query.get();

      return results.map(_mapToEntity).toList();
    } catch (e) {
      throw CacheException(
        message: 'Failed to get pending sync parents: $e',
      );
    }
  }

  @override
  Future<void> updateSyncStatus(String id, SyncStatus status) async {
    try {
      await (database.update(database.parents)..where((t) => t.id.equals(id)))
          .write(
        ParentsCompanion(
          syncStatus: Value(status),
          updatedAt: Value(DateTime.now()),
        ),
      );
    } catch (e) {
      throw CacheException(
        message: 'Failed to update sync status: $e',
      );
    }
  }

  entity.Parent _mapToEntity(Parent data) {
    return entity.Parent(
      id: data.id,
      name: data.name,
      email: data.email,
      createdAt: data.createdAt,
      updatedAt: data.updatedAt,
      syncStatus: data.syncStatus,
    );
  }
}
