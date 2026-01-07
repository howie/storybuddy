import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:storybuddy/core/network/connectivity_service.dart';
import 'package:storybuddy/core/sync/sync_manager.dart';

class MockConnectivityService extends Mock implements ConnectivityService {}

void main() {
  late SyncManager syncManager;
  late MockConnectivityService mockConnectivityService;

  setUp(() {
    mockConnectivityService = MockConnectivityService();
    syncManager = SyncManager(connectivityService: mockConnectivityService);
  });

  tearDown(() {
    syncManager.dispose();
  });

  group('SyncManager', () {
    group('initial state', () {
      test('should have idle state initially', () {
        expect(syncManager.status.state, SyncState.idle);
      });

      test('should have zero pending count initially', () {
        expect(syncManager.status.pendingCount, 0);
      });

      test('should not be syncing initially', () {
        expect(syncManager.status.isSyncing, false);
      });

      test('should not have pending changes initially', () {
        expect(syncManager.status.hasPendingChanges, false);
      });
    });

    group('registerHandler', () {
      test('should register a handler successfully', () async {
        when(() => mockConnectivityService.isConnected)
            .thenAnswer((_) async => true);

        syncManager.registerHandler('test', () async {
          return const SyncResult(success: true, itemsSynced: 5);
        });

        final result = await syncManager.syncDataType('test');

        expect(result.success, true);
        expect(result.itemsSynced, 5);
      });

      test('should return error for unregistered handler', () async {
        final result = await syncManager.syncDataType('nonexistent');

        expect(result.success, false);
        expect(result.errors, contains('No handler registered for nonexistent'));
      });
    });

    group('unregisterHandler', () {
      test('should unregister a handler successfully', () async {
        syncManager.registerHandler('test', () async {
          return const SyncResult(success: true);
        });

        syncManager.unregisterHandler('test');

        final result = await syncManager.syncDataType('test');

        expect(result.success, false);
        expect(result.errors, contains('No handler registered for test'));
      });
    });

    group('sync', () {
      test('should return failure when offline', () async {
        when(() => mockConnectivityService.isConnected)
            .thenAnswer((_) async => false);

        final result = await syncManager.sync();

        expect(result.success, false);
        expect(result.errors, contains('No network connection'));
      });

      test('should sync all registered handlers when online', () async {
        when(() => mockConnectivityService.isConnected)
            .thenAnswer((_) async => true);

        int handler1Called = 0;
        int handler2Called = 0;

        syncManager.registerHandler('type1', () async {
          handler1Called++;
          return const SyncResult(success: true, itemsSynced: 3);
        });

        syncManager.registerHandler('type2', () async {
          handler2Called++;
          return const SyncResult(success: true, itemsSynced: 2);
        });

        final result = await syncManager.sync();

        expect(result.success, true);
        expect(result.itemsSynced, 5);
        expect(handler1Called, 1);
        expect(handler2Called, 1);
      });

      test('should collect errors from failing handlers', () async {
        when(() => mockConnectivityService.isConnected)
            .thenAnswer((_) async => true);

        syncManager.registerHandler('failing', () async {
          return const SyncResult(
            success: false,
            errors: ['Something went wrong'],
          );
        });

        final result = await syncManager.sync();

        expect(result.success, false);
        expect(result.errors, contains('Something went wrong'));
      });

      test('should catch exceptions from handlers', () async {
        when(() => mockConnectivityService.isConnected)
            .thenAnswer((_) async => true);

        syncManager.registerHandler('throwing', () async {
          throw Exception('Handler error');
        });

        final result = await syncManager.sync();

        expect(result.success, false);
        expect(
          result.errors.any((e) => e.contains('throwing')),
          true,
        );
      });

      test('should not sync when already syncing', () async {
        when(() => mockConnectivityService.isConnected)
            .thenAnswer((_) async => true);

        final completer = Completer<SyncResult>();
        syncManager.registerHandler('slow', () => completer.future);

        // Start first sync (don't await)
        final firstSync = syncManager.sync();

        // Small delay to ensure first sync has started
        await Future.delayed(const Duration(milliseconds: 50));

        // Attempt second sync - should fail because first is still running
        final secondSync = await syncManager.sync();
        expect(secondSync.success, false);

        // Complete the first sync
        completer.complete(const SyncResult(success: true));
        final firstResult = await firstSync;
        expect(firstResult.success, true);
      });

      test('should update status during sync', () async {
        when(() => mockConnectivityService.isConnected)
            .thenAnswer((_) async => true);

        final statusUpdates = <SyncStatus>[];
        final subscription = syncManager.statusStream.listen(statusUpdates.add);

        syncManager.registerHandler('test', () async {
          return const SyncResult(success: true);
        });

        await syncManager.sync();

        // Wait for status updates
        await Future.delayed(const Duration(milliseconds: 100));

        expect(statusUpdates.any((s) => s.state == SyncState.syncing), true);
        expect(statusUpdates.any((s) => s.state == SyncState.completed), true);

        await subscription.cancel();
      });
    });

    group('syncDataType', () {
      test('should sync specific data type when online', () async {
        when(() => mockConnectivityService.isConnected)
            .thenAnswer((_) async => true);

        syncManager.registerHandler('stories', () async {
          return const SyncResult(success: true, itemsSynced: 10);
        });

        final result = await syncManager.syncDataType('stories');

        expect(result.success, true);
        expect(result.itemsSynced, 10);
      });

      test('should return failure when offline', () async {
        when(() => mockConnectivityService.isConnected)
            .thenAnswer((_) async => false);

        syncManager.registerHandler('stories', () async {
          return const SyncResult(success: true);
        });

        final result = await syncManager.syncDataType('stories');

        expect(result.success, false);
        expect(result.errors, contains('No network connection'));
      });
    });

    group('updatePendingCount', () {
      test('should update pending count in status', () {
        syncManager.updatePendingCount(5);

        expect(syncManager.status.pendingCount, 5);
        expect(syncManager.status.hasPendingChanges, true);
      });

      test('should emit status update when pending count changes', () async {
        final statusUpdates = <SyncStatus>[];
        final subscription = syncManager.statusStream.listen(statusUpdates.add);

        syncManager.updatePendingCount(3);

        await Future.delayed(const Duration(milliseconds: 50));

        expect(statusUpdates.last.pendingCount, 3);

        await subscription.cancel();
      });
    });

    group('autoSync', () {
      test('should start and stop auto sync', () {
        syncManager.startAutoSync(interval: const Duration(seconds: 1));
        // No exception means success
        syncManager.stopAutoSync();
        // No exception means success
      });
    });

    group('dispose', () {
      test('should not process sync after disposal', () async {
        when(() => mockConnectivityService.isConnected)
            .thenAnswer((_) async => true);

        syncManager.dispose();

        final result = await syncManager.sync();

        expect(result.success, false);
      });
    });
  });

  group('SyncResult', () {
    test('empty should have success true and zero items', () {
      expect(SyncResult.empty.success, true);
      expect(SyncResult.empty.itemsSynced, 0);
      expect(SyncResult.empty.errors, isEmpty);
    });
  });

  group('SyncStatus', () {
    test('isSyncing should return true only when syncing', () {
      const syncing = SyncStatus(state: SyncState.syncing);
      const idle = SyncStatus(state: SyncState.idle);
      const completed = SyncStatus(state: SyncState.completed);

      expect(syncing.isSyncing, true);
      expect(idle.isSyncing, false);
      expect(completed.isSyncing, false);
    });

    test('hasPendingChanges should return true when count > 0', () {
      const withPending = SyncStatus(pendingCount: 5);
      const withoutPending = SyncStatus(pendingCount: 0);

      expect(withPending.hasPendingChanges, true);
      expect(withoutPending.hasPendingChanges, false);
    });

    test('copyWith should create new instance with updated values', () {
      const original = SyncStatus(
        state: SyncState.idle,
        pendingCount: 0,
      );

      final updated = original.copyWith(
        state: SyncState.syncing,
        pendingCount: 5,
      );

      expect(updated.state, SyncState.syncing);
      expect(updated.pendingCount, 5);
      expect(original.state, SyncState.idle);
      expect(original.pendingCount, 0);
    });
  });
}
