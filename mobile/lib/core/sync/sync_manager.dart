import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../network/connectivity_service.dart';

part 'sync_manager.g.dart';

/// Status of a sync operation.
enum SyncState {
  idle,
  syncing,
  completed,
  failed,
}

/// Result of a sync operation.
class SyncResult {
  const SyncResult({
    required this.success,
    this.itemsSynced = 0,
    this.errors = const [],
  });

  final bool success;
  final int itemsSynced;
  final List<String> errors;

  static const SyncResult empty = SyncResult(success: true);
}

/// Status for the overall sync manager.
class SyncStatus {
  const SyncStatus({
    this.state = SyncState.idle,
    this.lastSyncAt,
    this.pendingCount = 0,
    this.lastError,
  });

  final SyncState state;
  final DateTime? lastSyncAt;
  final int pendingCount;
  final String? lastError;

  bool get isSyncing => state == SyncState.syncing;
  bool get hasPendingChanges => pendingCount > 0;

  SyncStatus copyWith({
    SyncState? state,
    DateTime? lastSyncAt,
    int? pendingCount,
    String? lastError,
  }) {
    return SyncStatus(
      state: state ?? this.state,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      pendingCount: pendingCount ?? this.pendingCount,
      lastError: lastError,
    );
  }
}

/// Manager for syncing data between local storage and remote API.
class SyncManager {
  SyncManager({
    required this.connectivityService,
  });

  final ConnectivityService connectivityService;

  final _statusController = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get statusStream => _statusController.stream;

  SyncStatus _status = const SyncStatus();
  SyncStatus get status => _status;

  Timer? _autoSyncTimer;
  bool _isDisposed = false;

  /// Registered sync handlers for different data types.
  final Map<String, Future<SyncResult> Function()> _handlers = {};

  /// Registers a sync handler for a data type.
  void registerHandler(String dataType, Future<SyncResult> Function() handler) {
    _handlers[dataType] = handler;
  }

  /// Unregisters a sync handler.
  void unregisterHandler(String dataType) {
    _handlers.remove(dataType);
  }

  /// Starts automatic background sync.
  void startAutoSync({
    Duration interval = const Duration(minutes: 5),
  }) {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer.periodic(interval, (_) => sync());
  }

  /// Stops automatic background sync.
  void stopAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;
  }

  /// Performs a full sync of all registered handlers.
  Future<SyncResult> sync() async {
    if (_isDisposed) return const SyncResult(success: false);
    if (_status.isSyncing) return const SyncResult(success: false);

    // Check connectivity
    if (!await connectivityService.isConnected) {
      return const SyncResult(
        success: false,
        errors: ['No network connection'],
      );
    }

    _updateStatus(_status.copyWith(
      state: SyncState.syncing,
      lastError: null,
    ));

    int totalSynced = 0;
    final errors = <String>[];

    for (final entry in _handlers.entries) {
      try {
        final result = await entry.value();
        totalSynced += result.itemsSynced;
        errors.addAll(result.errors);
      } catch (e) {
        errors.add('${entry.key}: $e');
        debugPrint('Sync error for ${entry.key}: $e');
      }
    }

    final success = errors.isEmpty;
    _updateStatus(_status.copyWith(
      state: success ? SyncState.completed : SyncState.failed,
      lastSyncAt: DateTime.now(),
      lastError: errors.isNotEmpty ? errors.first : null,
    ));

    // Reset to idle after a short delay
    Future.delayed(const Duration(seconds: 2), () {
      if (!_isDisposed && _status.state != SyncState.syncing) {
        _updateStatus(_status.copyWith(state: SyncState.idle));
      }
    });

    return SyncResult(
      success: success,
      itemsSynced: totalSynced,
      errors: errors,
    );
  }

  /// Syncs a specific data type.
  Future<SyncResult> syncDataType(String dataType) async {
    final handler = _handlers[dataType];
    if (handler == null) {
      return SyncResult(
        success: false,
        errors: ['No handler registered for $dataType'],
      );
    }

    if (!await connectivityService.isConnected) {
      return const SyncResult(
        success: false,
        errors: ['No network connection'],
      );
    }

    try {
      return await handler();
    } catch (e) {
      return SyncResult(
        success: false,
        errors: [e.toString()],
      );
    }
  }

  /// Updates the pending count.
  void updatePendingCount(int count) {
    _updateStatus(_status.copyWith(pendingCount: count));
  }

  void _updateStatus(SyncStatus newStatus) {
    _status = newStatus;
    if (!_isDisposed) {
      _statusController.add(_status);
    }
  }

  /// Disposes the sync manager.
  void dispose() {
    _isDisposed = true;
    _autoSyncTimer?.cancel();
    _statusController.close();
  }
}

/// Provider for SyncManager.
@riverpod
SyncManager syncManager(SyncManagerRef ref) {
  final connectivity = ref.watch(connectivityServiceProvider);
  final manager = SyncManager(connectivityService: connectivity);

  ref.onDispose(() {
    manager.dispose();
  });

  return manager;
}

/// Provider for sync status stream.
@riverpod
Stream<SyncStatus> syncStatusStream(SyncStatusStreamRef ref) {
  final manager = ref.watch(syncManagerProvider);
  return manager.statusStream;
}
