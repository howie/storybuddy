// T028-A [P] [US1] Unit test for mode switching logic.
// Tests the mid-playback mode switching logic as defined in FR-013.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:storybuddy/core/network/websocket_client.dart';
import 'package:storybuddy/features/interaction/domain/entities/interaction_session.dart';
// These imports will fail until the provider is implemented
import 'package:storybuddy/features/interaction/presentation/providers/interaction_provider.dart';

// Mock classes
class MockWebSocketClient extends Mock implements WebSocketClient {}

void main() {
  late InteractionNotifier notifier;
  late MockWebSocketClient mockWebSocketClient;

  setUp(() {
    mockWebSocketClient = MockWebSocketClient();
    notifier = InteractionNotifier(webSocketClient: mockWebSocketClient);
  });

  group('Mode Switching - Interactive to Passive (FR-013)', () {
    test('should close WebSocket when switching to passive mode', () async {
      // Arrange
      when(() => mockWebSocketClient.isConnected).thenReturn(true);
      when(() => mockWebSocketClient.disconnect()).thenAnswer((_) async {});

      notifier.state = InteractionState(
        sessionId: 'session-123',
        mode: SessionMode.interactive,
        status: SessionStatus.active,
        storyPositionMs: 30000,
      );

      // Act
      await notifier.switchMode(SessionMode.passive);

      // Assert
      verify(() => mockWebSocketClient.disconnect()).called(1);
    });

    test('should stop VAD when switching to passive mode', () async {
      // Arrange
      when(() => mockWebSocketClient.disconnect()).thenAnswer((_) async {});

      notifier.state = InteractionState(
        sessionId: 'session-123',
        mode: SessionMode.interactive,
        status: SessionStatus.active,
        isListening: true,
      );

      // Act
      await notifier.switchMode(SessionMode.passive);

      // Assert
      expect(notifier.state.isListening, isFalse);
    });

    test('should send end_session message before disconnecting', () async {
      // Arrange
      when(() => mockWebSocketClient.isConnected).thenReturn(true);
      when(() => mockWebSocketClient.sendMessage(any()))
          .thenAnswer((_) async {});
      when(() => mockWebSocketClient.disconnect()).thenAnswer((_) async {});

      notifier.state = InteractionState(
        sessionId: 'session-123',
        mode: SessionMode.interactive,
        status: SessionStatus.active,
      );

      // Act
      await notifier.switchMode(SessionMode.passive);

      // Assert
      verify(() => mockWebSocketClient.sendMessage(
            argThat(
              predicate<Map<String, dynamic>>(
                (msg) => msg['type'] == 'end_session',
              ),
            ),
          ),).called(1);
    });

    test('should preserve story position when switching modes', () async {
      // Arrange
      when(() => mockWebSocketClient.disconnect()).thenAnswer((_) async {});

      const initialPosition = 45000; // 45 seconds
      notifier.state = InteractionState(
        sessionId: 'session-123',
        mode: SessionMode.interactive,
        status: SessionStatus.active,
        storyPositionMs: initialPosition,
      );

      // Act
      await notifier.switchMode(SessionMode.passive);

      // Assert
      expect(notifier.state.storyPositionMs, equals(initialPosition));
    });

    test('should update mode to passive after switching', () async {
      // Arrange
      when(() => mockWebSocketClient.disconnect()).thenAnswer((_) async {});

      notifier.state = InteractionState(
        sessionId: 'session-123',
        mode: SessionMode.interactive,
        status: SessionStatus.active,
      );

      // Act
      await notifier.switchMode(SessionMode.passive);

      // Assert
      expect(notifier.state.mode, equals(SessionMode.passive));
    });
  });

  group('Mode Switching - Passive to Interactive (FR-013)', () {
    test('should start calibration when switching to interactive mode',
        () async {
      // Arrange
      notifier.state = InteractionState(
        sessionId: 'session-123',
        mode: SessionMode.passive,
        status: SessionStatus.active,
        storyPositionMs: 30000,
      );

      // Act
      await notifier.switchMode(SessionMode.interactive);

      // Assert
      expect(notifier.state.status, equals(SessionStatus.calibrating));
    });

    test('should establish WebSocket after calibration', () async {
      // Arrange
      when(() => mockWebSocketClient.connect(
            sessionId: any(named: 'sessionId'),
            token: any(named: 'token'),
          ),).thenAnswer((_) async {});

      notifier.state = InteractionState(
        sessionId: 'session-123',
        mode: SessionMode.passive,
        status: SessionStatus.active,
      );

      // Act
      await notifier.switchMode(SessionMode.interactive);
      // Simulate calibration complete
      await notifier.completeCalibration();

      // Assert
      verify(() => mockWebSocketClient.connect(
            sessionId: 'session-123',
            token: any(named: 'token'),
          ),).called(1);
    });

    test('should sync story position when establishing WebSocket', () async {
      // Arrange
      when(() => mockWebSocketClient.connect(
            sessionId: any(named: 'sessionId'),
            token: any(named: 'token'),
          ),).thenAnswer((_) async {});
      when(() => mockWebSocketClient.sendMessage(any()))
          .thenAnswer((_) async {});

      const currentPosition = 60000; // 60 seconds
      notifier.state = InteractionState(
        sessionId: 'session-123',
        mode: SessionMode.passive,
        status: SessionStatus.active,
        storyPositionMs: currentPosition,
      );

      // Act
      await notifier.switchMode(SessionMode.interactive);
      await notifier.completeCalibration();

      // Assert
      verify(() => mockWebSocketClient.sendMessage(
            argThat(
              predicate<Map<String, dynamic>>(
                (msg) =>
                    msg['type'] == 'sync_position' &&
                    msg['positionMs'] == currentPosition,
              ),
            ),
          ),).called(1);
    });

    test('should update mode to interactive after switching', () async {
      // Arrange
      notifier.state = InteractionState(
        sessionId: 'session-123',
        mode: SessionMode.passive,
        status: SessionStatus.active,
      );

      // Act
      await notifier.switchMode(SessionMode.interactive);

      // Assert
      expect(notifier.state.mode, equals(SessionMode.interactive));
    });

    test('should activate VAD after calibration completes', () async {
      // Arrange
      when(() => mockWebSocketClient.connect(
            sessionId: any(named: 'sessionId'),
            token: any(named: 'token'),
          ),).thenAnswer((_) async {});

      notifier.state = InteractionState(
        sessionId: 'session-123',
        mode: SessionMode.passive,
        status: SessionStatus.active,
      );

      // Act
      await notifier.switchMode(SessionMode.interactive);
      await notifier.completeCalibration();

      // Assert
      expect(notifier.state.isListening, isTrue);
    });
  });

  group('Mode Switching - Edge Cases', () {
    test('should handle switching while child is speaking', () async {
      // Arrange
      when(() => mockWebSocketClient.disconnect()).thenAnswer((_) async {});
      when(() => mockWebSocketClient.sendMessage(any()))
          .thenAnswer((_) async {});

      notifier.state = InteractionState(
        sessionId: 'session-123',
        mode: SessionMode.interactive,
        status: SessionStatus.active,
        isChildSpeaking: true,
      );

      // Act
      await notifier.switchMode(SessionMode.passive);

      // Assert - should stop speech detection
      expect(notifier.state.isChildSpeaking, isFalse);
    });

    test('should handle switching while AI is responding', () async {
      // Arrange
      when(() => mockWebSocketClient.disconnect()).thenAnswer((_) async {});
      when(() => mockWebSocketClient.sendMessage(any()))
          .thenAnswer((_) async {});

      notifier.state = InteractionState(
        sessionId: 'session-123',
        mode: SessionMode.interactive,
        status: SessionStatus.active,
        isAIResponding: true,
        currentAIResponseText: '小兔子很勇敢喔！',
      );

      // Act
      await notifier.switchMode(SessionMode.passive);

      // Assert - should clear AI response state
      expect(notifier.state.isAIResponding, isFalse);
      expect(notifier.state.currentAIResponseText, isEmpty);
    });

    test('should not switch if already in target mode', () async {
      // Arrange
      notifier.state = InteractionState(
        sessionId: 'session-123',
        mode: SessionMode.interactive,
        status: SessionStatus.active,
      );

      // Act
      await notifier.switchMode(SessionMode.interactive);

      // Assert - should not trigger any actions
      verifyNever(() => mockWebSocketClient.disconnect());
      verifyNever(() => mockWebSocketClient.connect(
            sessionId: any(named: 'sessionId'),
            token: any(named: 'token'),
          ),);
    });

    test('should handle network error during mode switch gracefully', () async {
      // Arrange
      when(() => mockWebSocketClient.disconnect())
          .thenThrow(Exception('Network error'));

      notifier.state = InteractionState(
        sessionId: 'session-123',
        mode: SessionMode.interactive,
        status: SessionStatus.active,
      );

      // Act & Assert - should not throw
      await expectLater(
        () => notifier.switchMode(SessionMode.passive),
        returnsNormally,
      );

      // Should still update mode
      expect(notifier.state.mode, equals(SessionMode.passive));
    });

    test('should pause story playback during calibration', () async {
      // Arrange
      notifier.state = InteractionState(
        sessionId: 'session-123',
        mode: SessionMode.passive,
        status: SessionStatus.active,
        isPlaying: true,
      );

      // Act
      await notifier.switchMode(SessionMode.interactive);

      // Assert - story should be paused during calibration
      expect(notifier.state.isPlaying, isFalse);
    });

    test('should resume story playback after calibration completes', () async {
      // Arrange
      when(() => mockWebSocketClient.connect(
            sessionId: any(named: 'sessionId'),
            token: any(named: 'token'),
          ),).thenAnswer((_) async {});

      notifier.state = InteractionState(
        sessionId: 'session-123',
        mode: SessionMode.passive,
        status: SessionStatus.active,
        isPlaying: true,
        wasPlayingBeforeCalibration: true,
      );

      await notifier.switchMode(SessionMode.interactive);

      // Act
      await notifier.completeCalibration();

      // Assert - story should resume
      expect(notifier.state.isPlaying, isTrue);
    });
  });

  group('Mode Switching - State Transitions', () {
    test(
        'state transitions should be: active -> switching -> calibrating/active',
        () async {
      // Arrange
      final states = <SessionStatus>[];
      notifier.addListener(() {
        states.add(notifier.state.status);
      });

      notifier.state = InteractionState(
        sessionId: 'session-123',
        mode: SessionMode.passive,
        status: SessionStatus.active,
      );

      // Act
      await notifier.switchMode(SessionMode.interactive);

      // Assert
      expect(states, contains(SessionStatus.calibrating));
    });

    test('should emit mode change event', () async {
      // Arrange
      final modeChanges = <SessionMode>[];
      notifier.addListener(() {
        modeChanges.add(notifier.state.mode);
      });

      notifier.state = InteractionState(
        sessionId: 'session-123',
        mode: SessionMode.passive,
        status: SessionStatus.active,
      );

      // Act
      await notifier.switchMode(SessionMode.interactive);

      // Assert
      expect(modeChanges, contains(SessionMode.interactive));
    });
  });
}
