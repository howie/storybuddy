import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:storybuddy/core/network/connectivity_service.dart';

class MockConnectivity extends Mock implements Connectivity {}

void main() {
  late ConnectivityService service;
  late MockConnectivity mockConnectivity;

  setUp(() {
    mockConnectivity = MockConnectivity();
    service = ConnectivityService(connectivity: mockConnectivity);
  });

  group('ConnectivityService', () {
    group('isConnected', () {
      test('returns true when connected via WiFi', () async {
        // Arrange
        when(() => mockConnectivity.checkConnectivity())
            .thenAnswer((_) async => [ConnectivityResult.wifi]);

        // Act
        final result = await service.isConnected;

        // Assert
        expect(result, true);
        verify(() => mockConnectivity.checkConnectivity()).called(1);
      });

      test('returns true when connected via mobile data', () async {
        // Arrange
        when(() => mockConnectivity.checkConnectivity())
            .thenAnswer((_) async => [ConnectivityResult.mobile]);

        // Act
        final result = await service.isConnected;

        // Assert
        expect(result, true);
      });

      test('returns true when connected via ethernet', () async {
        // Arrange
        when(() => mockConnectivity.checkConnectivity())
            .thenAnswer((_) async => [ConnectivityResult.ethernet]);

        // Act
        final result = await service.isConnected;

        // Assert
        expect(result, true);
      });

      test('returns true when multiple connections available', () async {
        // Arrange
        when(() => mockConnectivity.checkConnectivity())
            .thenAnswer((_) async => [
                  ConnectivityResult.wifi,
                  ConnectivityResult.mobile,
                ]);

        // Act
        final result = await service.isConnected;

        // Assert
        expect(result, true);
      });

      test('returns false when no connection', () async {
        // Arrange
        when(() => mockConnectivity.checkConnectivity())
            .thenAnswer((_) async => [ConnectivityResult.none]);

        // Act
        final result = await service.isConnected;

        // Assert
        expect(result, false);
      });

      test('returns false when only Bluetooth available', () async {
        // Arrange
        when(() => mockConnectivity.checkConnectivity())
            .thenAnswer((_) async => [ConnectivityResult.bluetooth]);

        // Act
        final result = await service.isConnected;

        // Assert
        expect(result, false);
      });

      test('returns false when empty list', () async {
        // Arrange
        when(() => mockConnectivity.checkConnectivity())
            .thenAnswer((_) async => []);

        // Act
        final result = await service.isConnected;

        // Assert
        expect(result, false);
      });
    });

    group('onConnectivityChanged', () {
      test('emits true when WiFi connected', () async {
        // Arrange
        final controller = StreamController<List<ConnectivityResult>>();
        when(() => mockConnectivity.onConnectivityChanged)
            .thenAnswer((_) => controller.stream);

        // Act
        final stream = service.onConnectivityChanged;

        // Assert
        expectLater(stream, emits(true));
        controller.add([ConnectivityResult.wifi]);

        await controller.close();
      });

      test('emits false when disconnected', () async {
        // Arrange
        final controller = StreamController<List<ConnectivityResult>>();
        when(() => mockConnectivity.onConnectivityChanged)
            .thenAnswer((_) => controller.stream);

        // Act
        final stream = service.onConnectivityChanged;

        // Assert
        expectLater(stream, emits(false));
        controller.add([ConnectivityResult.none]);

        await controller.close();
      });

      test('emits sequence of connectivity changes', () async {
        // Arrange
        final controller = StreamController<List<ConnectivityResult>>();
        when(() => mockConnectivity.onConnectivityChanged)
            .thenAnswer((_) => controller.stream);

        // Act
        final stream = service.onConnectivityChanged;

        // Assert
        expectLater(stream, emitsInOrder([true, false, true]));
        controller.add([ConnectivityResult.wifi]);
        controller.add([ConnectivityResult.none]);
        controller.add([ConnectivityResult.mobile]);

        await controller.close();
      });
    });
  });
}
