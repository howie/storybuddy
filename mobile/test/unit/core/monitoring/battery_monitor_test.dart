import 'package:battery_plus/battery_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:storybuddy/core/monitoring/battery_monitor.dart';

class MockBattery extends Mock implements Battery {}

void main() {
  group('BatteryMonitor', () {
    late MockBattery mockBattery;
    late BatteryMonitor monitor;

    setUp(() {
      mockBattery = MockBattery();
      when(() => mockBattery.batteryLevel).thenAnswer((_) async => 75);
      when(() => mockBattery.batteryState)
          .thenAnswer((_) async => BatteryState.discharging);
      when(() => mockBattery.onBatteryStateChanged)
          .thenAnswer((_) => const Stream.empty());

      monitor = BatteryMonitor(battery: mockBattery);
    });

    tearDown(() {
      monitor.dispose();
    });

    test('should initialize with current battery state', () async {
      await monitor.initialize();

      expect(monitor.currentLevel, 75);
      expect(monitor.currentState, BatteryState.discharging);
      expect(monitor.isCharging, false);
    });

    test('should report charging when battery is charging', () async {
      when(() => mockBattery.batteryState)
          .thenAnswer((_) async => BatteryState.charging);

      await monitor.initialize();

      expect(monitor.isCharging, true);
    });

    test('should report charging when battery is full', () async {
      when(() => mockBattery.batteryState)
          .thenAnswer((_) async => BatteryState.full);

      await monitor.initialize();

      expect(monitor.isCharging, true);
    });

    test('should detect low battery below 25%', () async {
      when(() => mockBattery.batteryLevel).thenAnswer((_) async => 20);

      await monitor.initialize();

      expect(monitor.isLow, true);
      expect(monitor.isCriticallyLow, false);
    });

    test('should detect critically low battery below 15%', () async {
      when(() => mockBattery.batteryLevel).thenAnswer((_) async => 10);

      await monitor.initialize();

      expect(monitor.isLow, true);
      expect(monitor.isCriticallyLow, true);
    });

    test('should track session battery consumption', () async {
      await monitor.initialize();

      await monitor.startSession();

      // Simulate battery drain
      when(() => mockBattery.batteryLevel).thenAnswer((_) async => 70);

      final stats = await monitor.endSession();

      expect(stats, isNotNull);
      expect(stats!.startLevel, 75);
      expect(stats.endLevel, 70);
      expect(stats.consumption, 5);
    });

    test('should return null stats if session not started', () async {
      await monitor.initialize();

      final stats = await monitor.endSession();

      expect(stats, isNull);
    });
  });

  group('BatterySessionStats', () {
    test('should calculate consumption per hour', () {
      const stats = BatterySessionStats(
        startLevel: 100,
        endLevel: 90,
        duration: Duration(minutes: 30),
        snapshots: [],
        wasChargingDuringSession: false,
      );

      expect(stats.consumption, 10);
      expect(stats.consumptionPerHour, 20.0);
    });

    test('should indicate significant drain', () {
      const stats = BatterySessionStats(
        startLevel: 100,
        endLevel: 90,
        duration: Duration(hours: 1),
        snapshots: [],
        wasChargingDuringSession: false,
      );

      expect(stats.hadSignificantDrain, true);
    });

    test('should not indicate significant drain when charging', () {
      const stats = BatterySessionStats(
        startLevel: 80,
        endLevel: 100,
        duration: Duration(hours: 1),
        snapshots: [],
        wasChargingDuringSession: true,
      );

      expect(stats.hadSignificantDrain, false);
    });

    test('should provide summary for charging session', () {
      const stats = BatterySessionStats(
        startLevel: 80,
        endLevel: 100,
        duration: Duration(hours: 1),
        snapshots: [],
        wasChargingDuringSession: true,
      );

      expect(stats.summary, '充電中使用 - 電池已充電');
    });

    test('should provide summary for high power usage', () {
      const stats = BatterySessionStats(
        startLevel: 100,
        endLevel: 70,
        duration: Duration(hours: 1),
        snapshots: [],
        wasChargingDuringSession: false,
      );

      expect(stats.summary, contains('高耗電量'));
    });

    test('should provide summary for low power usage', () {
      const stats = BatterySessionStats(
        startLevel: 100,
        endLevel: 95,
        duration: Duration(hours: 1),
        snapshots: [],
        wasChargingDuringSession: false,
      );

      expect(stats.summary, contains('低耗電量'));
    });
  });
}
