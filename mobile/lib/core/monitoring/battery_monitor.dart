import 'dart:async';

import 'package:battery_plus/battery_plus.dart';

/// T099 [P] Battery monitoring for interaction sessions.
///
/// Tracks battery usage during interactive sessions to help users
/// understand power consumption and make informed decisions.
class BatteryMonitor {
  BatteryMonitor({
    Battery? battery,
  }) : _battery = battery ?? Battery();

  final Battery _battery;
  StreamSubscription? _stateSubscription;

  // Session tracking
  DateTime? _sessionStartTime;
  int? _startBatteryLevel;
  BatteryState? _currentState;
  int? _currentLevel;

  // Accumulated stats
  final List<BatterySnapshot> _snapshots = [];
  static const _snapshotInterval = Duration(minutes: 5);
  Timer? _snapshotTimer;

  /// Current battery level (0-100).
  int? get currentLevel => _currentLevel;

  /// Current battery state.
  BatteryState? get currentState => _currentState;

  /// Whether the device is charging.
  bool get isCharging =>
      _currentState == BatteryState.charging ||
      _currentState == BatteryState.full;

  /// Initialize battery monitoring.
  Future<void> initialize() async {
    try {
      _currentLevel = await _battery.batteryLevel;
      _currentState = await _battery.batteryState;

      // Subscribe to state changes
      _stateSubscription = _battery.onBatteryStateChanged.listen((state) {
        _currentState = state;
      });
    } catch (e) {
      // Battery monitoring not available on this device
      _currentLevel = null;
      _currentState = null;
    }
  }

  /// Start tracking battery usage for a session.
  Future<void> startSession() async {
    _sessionStartTime = DateTime.now();
    _startBatteryLevel = await _getBatteryLevel();
    _snapshots.clear();

    // Take periodic snapshots
    _snapshotTimer?.cancel();
    _snapshotTimer = Timer.periodic(_snapshotInterval, (_) async {
      await _takeSnapshot();
    });

    // Take initial snapshot
    await _takeSnapshot();
  }

  /// Stop tracking and return session stats.
  Future<BatterySessionStats?> endSession() async {
    _snapshotTimer?.cancel();
    _snapshotTimer = null;

    if (_sessionStartTime == null || _startBatteryLevel == null) {
      return null;
    }

    final endLevel = await _getBatteryLevel();
    final duration = DateTime.now().difference(_sessionStartTime!);

    // Take final snapshot
    await _takeSnapshot();

    final stats = BatterySessionStats(
      startLevel: _startBatteryLevel!,
      endLevel: endLevel ?? _startBatteryLevel!,
      duration: duration,
      snapshots: List.unmodifiable(_snapshots),
      wasChargingDuringSession: _snapshots.any((s) => s.isCharging),
    );

    _sessionStartTime = null;
    _startBatteryLevel = null;

    return stats;
  }

  Future<int?> _getBatteryLevel() async {
    try {
      _currentLevel = await _battery.batteryLevel;
      return _currentLevel;
    } catch (e) {
      return null;
    }
  }

  Future<void> _takeSnapshot() async {
    final level = await _getBatteryLevel();
    if (level == null) return;

    _snapshots.add(BatterySnapshot(
      timestamp: DateTime.now(),
      level: level,
      isCharging: isCharging,
    ));
  }

  /// Get estimated remaining interactive time based on current drain rate.
  Duration? estimateRemainingTime() {
    if (_snapshots.length < 2) return null;
    if (isCharging) return null;

    // Calculate average drain rate from snapshots
    final firstSnapshot = _snapshots.first;
    final lastSnapshot = _snapshots.last;

    final levelDrop = firstSnapshot.level - lastSnapshot.level;
    if (levelDrop <= 0) return null; // No drain or charging

    final elapsed = lastSnapshot.timestamp.difference(firstSnapshot.timestamp);
    if (elapsed.inMinutes < 1) return null;

    // Calculate drain rate (% per minute)
    final drainRatePerMinute = levelDrop / elapsed.inMinutes;
    if (drainRatePerMinute <= 0) return null;

    // Estimate remaining time
    final currentLevel = _currentLevel ?? lastSnapshot.level;
    final minutesRemaining = currentLevel / drainRatePerMinute;

    return Duration(minutes: minutesRemaining.round());
  }

  /// Check if battery is critically low (below 15%).
  bool get isCriticallyLow => (_currentLevel ?? 100) < 15;

  /// Check if battery is low (below 25%).
  bool get isLow => (_currentLevel ?? 100) < 25;

  /// Dispose of resources.
  void dispose() {
    _stateSubscription?.cancel();
    _snapshotTimer?.cancel();
  }
}

/// A snapshot of battery state at a point in time.
class BatterySnapshot {
  const BatterySnapshot({
    required this.timestamp,
    required this.level,
    required this.isCharging,
  });

  final DateTime timestamp;
  final int level;
  final bool isCharging;
}

/// Statistics for a battery-tracked session.
class BatterySessionStats {
  const BatterySessionStats({
    required this.startLevel,
    required this.endLevel,
    required this.duration,
    required this.snapshots,
    required this.wasChargingDuringSession,
  });

  final int startLevel;
  final int endLevel;
  final Duration duration;
  final List<BatterySnapshot> snapshots;
  final bool wasChargingDuringSession;

  /// Battery percentage consumed during session.
  int get consumption => startLevel - endLevel;

  /// Average consumption per hour.
  double get consumptionPerHour {
    if (duration.inMinutes < 1) return 0;
    return (consumption / duration.inMinutes) * 60;
  }

  /// Whether the session had significant battery drain.
  bool get hadSignificantDrain => consumption > 5 && !wasChargingDuringSession;

  /// Human-readable summary of battery usage.
  String get summary {
    if (wasChargingDuringSession) {
      return '充電中使用 - 電池已充電';
    }

    if (consumption <= 0) {
      return '電池使用量極低';
    }

    if (consumptionPerHour > 20) {
      return '高耗電量 (每小時約 ${consumptionPerHour.toStringAsFixed(1)}%)';
    } else if (consumptionPerHour > 10) {
      return '中等耗電量 (每小時約 ${consumptionPerHour.toStringAsFixed(1)}%)';
    } else {
      return '低耗電量 (每小時約 ${consumptionPerHour.toStringAsFixed(1)}%)';
    }
  }
}
