import 'package:uuid/uuid.dart';

import '../../../../core/database/enums.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/connectivity_service.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../domain/entities/parent.dart';
import '../../domain/repositories/parent_repository.dart';
import '../datasources/parent_local_datasource.dart';
import '../datasources/parent_remote_datasource.dart';
import '../models/parent_model.dart';

/// Implementation of [ParentRepository].
class ParentRepositoryImpl implements ParentRepository {
  ParentRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.connectivityService,
    required this.secureStorage,
  });

  final ParentRemoteDataSource remoteDataSource;
  final ParentLocalDataSource localDataSource;
  final ConnectivityService connectivityService;
  final SecureStorageService secureStorage;

  @override
  Future<Parent?> getCurrentParent() async {
    final parentId = await getCurrentParentId();
    if (parentId == null) return null;
    return getParent(parentId);
  }

  @override
  Future<Parent?> getParent(String id) async {
    // Try local first
    final localParent = await localDataSource.getParent(id);

    // If online, try to refresh from remote
    if (await connectivityService.isConnected) {
      try {
        final remoteParent = await remoteDataSource.getParent(id);
        final entity = remoteParent.toEntity();
        await localDataSource.saveParent(entity);
        return entity;
      } on NotFoundException {
        // If not found on server but exists locally, it might be deleted
        if (localParent != null && localParent.isSynced) {
          await localDataSource.deleteParent(id);
          return null;
        }
      } catch (e) {
        // Network error, return local if available
        if (localParent != null) return localParent;
        rethrow;
      }
    }

    return localParent;
  }

  @override
  Future<Parent?> getParentByEmail(String email) async {
    // Try remote first since we don't have email-based local lookup
    if (await connectivityService.isConnected) {
      try {
        final remoteParent = await remoteDataSource.getParentByEmail(email);
        if (remoteParent != null) {
          final entity = remoteParent.toEntity();
          await localDataSource.saveParent(entity);
          return entity;
        }
      } catch (e) {
        // Network error, can't lookup by email locally
        return null;
      }
    }
    return null;
  }

  @override
  Future<Parent> createParent({
    required String name,
    String? email,
  }) async {
    final id = const Uuid().v4();
    final parent = Parent.create(id: id, name: name, email: email);

    // Save locally first (optimistic)
    await localDataSource.saveParent(parent);

    // Try to sync if online
    if (await connectivityService.isConnected) {
      try {
        final request = CreateParentRequest(name: name, email: email);
        final remoteParent = await remoteDataSource.createParent(request);
        final syncedParent = remoteParent.toEntity();
        await localDataSource.saveParent(syncedParent);
        await setCurrentParentId(syncedParent.id);
        return syncedParent;
      } catch (e) {
        // Keep local version with pending sync status
        await setCurrentParentId(parent.id);
        return parent;
      }
    }

    await setCurrentParentId(parent.id);
    return parent;
  }

  @override
  Future<Parent> updateParent({
    required String id,
    String? name,
    String? email,
  }) async {
    final existingParent = await localDataSource.getParent(id);
    if (existingParent == null) {
      throw const NotFoundException(
        message: 'Parent not found',
        resourceType: 'Parent',
      );
    }

    final updatedParent = existingParent.copyWith(
      name: name ?? existingParent.name,
      email: email ?? existingParent.email,
      updatedAt: DateTime.now(),
      syncStatus: SyncStatus.pendingSync,
    );

    await localDataSource.updateParent(updatedParent);

    // Try to sync if online
    if (await connectivityService.isConnected) {
      try {
        final request = UpdateParentRequest(name: name, email: email);
        final remoteParent = await remoteDataSource.updateParent(id, request);
        final syncedParent = remoteParent.toEntity();
        await localDataSource.saveParent(syncedParent);
        return syncedParent;
      } catch (e) {
        // Keep local version with pending sync status
        return updatedParent;
      }
    }

    return updatedParent;
  }

  @override
  Future<void> deleteParent(String id) async {
    // Delete locally first
    await localDataSource.deleteParent(id);

    // Clear current parent ID if it matches
    final currentId = await getCurrentParentId();
    if (currentId == id) {
      await secureStorage.clearParentId();
    }

    // Try to delete from server if online
    if (await connectivityService.isConnected) {
      try {
        await remoteDataSource.deleteParent(id);
      } catch (e) {
        // Log error but don't throw - local delete succeeded
      }
    }
  }

  @override
  Future<void> syncParent(String id) async {
    if (!await connectivityService.isConnected) {
      throw const NetworkException(message: 'No network connection');
    }

    final localParent = await localDataSource.getParent(id);
    if (localParent == null) return;

    if (localParent.syncStatus == SyncStatus.pendingSync) {
      try {
        final request = UpdateParentRequest(
          name: localParent.name,
          email: localParent.email,
        );
        final remoteParent = await remoteDataSource.updateParent(id, request);
        await localDataSource.saveParent(remoteParent.toEntity());
      } catch (e) {
        await localDataSource.updateSyncStatus(id, SyncStatus.syncFailed);
        rethrow;
      }
    }
  }

  @override
  Future<void> saveParentLocally(Parent parent) async {
    await localDataSource.saveParent(parent);
  }

  @override
  Future<void> setCurrentParentId(String id) async {
    await secureStorage.setParentId(id);
  }

  @override
  Future<String?> getCurrentParentId() async {
    return secureStorage.getParentId();
  }
}
