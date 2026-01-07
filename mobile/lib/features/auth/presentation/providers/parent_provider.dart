import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/connectivity_service.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../../../shared/providers/database_provider.dart';
import '../../data/datasources/parent_local_datasource.dart';
import '../../data/datasources/parent_remote_datasource.dart';
import '../../data/repositories/parent_repository_impl.dart';
import '../../domain/entities/parent.dart' as entity;
import '../../domain/repositories/parent_repository.dart';

/// Provider for the parent remote data source.
final parentRemoteDataSourceProvider = Provider<ParentRemoteDataSource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ParentRemoteDataSourceImpl(apiClient: apiClient);
});

/// Provider for the parent local data source.
final parentLocalDataSourceProvider = Provider<ParentLocalDataSource>((ref) {
  final database = ref.watch(databaseProvider);
  return ParentLocalDataSourceImpl(database: database);
});

/// Provider for the parent repository.
final parentRepositoryProvider = Provider<ParentRepository>((ref) {
  return ParentRepositoryImpl(
    remoteDataSource: ref.watch(parentRemoteDataSourceProvider),
    localDataSource: ref.watch(parentLocalDataSourceProvider),
    connectivityService: ref.watch(connectivityServiceProvider),
    secureStorage: ref.watch(secureStorageServiceProvider),
  );
});

/// Provider for the current parent.
final currentParentProvider = FutureProvider<entity.Parent?>((ref) async {
  final repository = ref.watch(parentRepositoryProvider);
  return repository.getCurrentParent();
});

/// Provider for checking if a parent is set up.
final isParentSetUpProvider = FutureProvider<bool>((ref) async {
  final parent = await ref.watch(currentParentProvider.future);
  return parent != null;
});

/// Notifier for parent state management.
class ParentNotifier extends StateNotifier<AsyncValue<entity.Parent?>> {
  ParentNotifier(this._repository) : super(const AsyncValue.loading()) {
    _loadCurrentParent();
  }

  final ParentRepository _repository;

  Future<void> _loadCurrentParent() async {
    state = const AsyncValue.loading();
    try {
      final parent = await _repository.getCurrentParent();
      state = AsyncValue.data(parent);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Creates a new parent.
  Future<void> createParent({
    required String name,
    String? email,
  }) async {
    state = const AsyncValue.loading();
    try {
      final parent = await _repository.createParent(
        name: name,
        email: email,
      );
      state = AsyncValue.data(parent);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Updates the current parent.
  Future<void> updateParent({
    String? name,
    String? email,
  }) async {
    final currentParent = state.value;
    if (currentParent == null) return;

    state = const AsyncValue.loading();
    try {
      final parent = await _repository.updateParent(
        id: currentParent.id,
        name: name,
        email: email,
      );
      state = AsyncValue.data(parent);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Refreshes the current parent.
  Future<void> refresh() async {
    await _loadCurrentParent();
  }
}

/// Provider for the parent notifier.
final parentNotifierProvider =
    StateNotifierProvider<ParentNotifier, AsyncValue<entity.Parent?>>((ref) {
  final repository = ref.watch(parentRepositoryProvider);
  return ParentNotifier(repository);
});
