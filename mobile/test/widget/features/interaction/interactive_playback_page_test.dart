// T028 [P] [US1] Widget test for interactive playback page.
// Tests the interactive playback page UI and interactions.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:storybuddy/features/interaction/domain/entities/interaction_session.dart';
// These imports will fail until the widgets are implemented
import 'package:storybuddy/features/interaction/presentation/pages/interactive_playback_page.dart';
import 'package:storybuddy/features/interaction/presentation/providers/interaction_provider.dart';
import 'package:storybuddy/features/interaction/presentation/widgets/interaction_indicator.dart';
import 'package:storybuddy/shared/widgets/mode_toggle.dart';

// Mock classes
class MockInteractionNotifier extends Mock implements InteractionNotifier {}

class MockInteractionSession extends Mock implements InteractionSession {}

void main() {
  late MockInteractionNotifier mockInteractionNotifier;

  setUp(() {
    mockInteractionNotifier = MockInteractionNotifier();
  });

  group('InteractivePlaybackPage', () {
    testWidgets('should display story title', (tester) async {
      // Arrange
      when(() => mockInteractionNotifier.state).thenReturn(
        InteractionState.initial(),
      );

      // Act
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            interactionProvider.overrideWith(() => mockInteractionNotifier),
          ],
          child: const MaterialApp(
            home: InteractivePlaybackPage(
              storyId: 'story-123',
              storyTitle: '小兔子的冒險',
            ),
          ),
        ),
      );

      // Assert
      expect(find.text('小兔子的冒險'), findsOneWidget);
    });

    testWidgets('should display mode toggle', (tester) async {
      // Arrange
      when(() => mockInteractionNotifier.state).thenReturn(
        InteractionState.initial(),
      );

      // Act
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            interactionProvider.overrideWith(() => mockInteractionNotifier),
          ],
          child: const MaterialApp(
            home: InteractivePlaybackPage(
              storyId: 'story-123',
              storyTitle: '小兔子的冒險',
            ),
          ),
        ),
      );

      // Assert
      expect(find.byType(ModeToggle), findsOneWidget);
    });

    testWidgets(
        'should show interactive mode indicator when in interactive mode',
        (tester) async {
      // Arrange
      when(() => mockInteractionNotifier.state).thenReturn(
        InteractionState(
          mode: SessionMode.interactive,
          status: SessionStatus.active,
          isListening: true,
        ),
      );

      // Act
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            interactionProvider.overrideWith(() => mockInteractionNotifier),
          ],
          child: const MaterialApp(
            home: InteractivePlaybackPage(
              storyId: 'story-123',
              storyTitle: '小兔子的冒險',
            ),
          ),
        ),
      );

      // Assert
      expect(find.byType(InteractionIndicator), findsOneWidget);
    });

    testWidgets('should display calibration dialog during calibration',
        (tester) async {
      // Arrange
      when(() => mockInteractionNotifier.state).thenReturn(
        InteractionState(
          mode: SessionMode.interactive,
          status: SessionStatus.calibrating,
        ),
      );

      // Act
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            interactionProvider.overrideWith(() => mockInteractionNotifier),
          ],
          child: const MaterialApp(
            home: InteractivePlaybackPage(
              storyId: 'story-123',
              storyTitle: '小兔子的冒險',
            ),
          ),
        ),
      );

      // Assert
      expect(find.text('正在校準環境噪音...'), findsOneWidget);
    });

    testWidgets('should display microphone icon when listening',
        (tester) async {
      // Arrange
      when(() => mockInteractionNotifier.state).thenReturn(
        InteractionState(
          mode: SessionMode.interactive,
          status: SessionStatus.active,
          isListening: true,
        ),
      );

      // Act
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            interactionProvider.overrideWith(() => mockInteractionNotifier),
          ],
          child: const MaterialApp(
            home: InteractivePlaybackPage(
              storyId: 'story-123',
              storyTitle: '小兔子的冒險',
            ),
          ),
        ),
      );

      // Assert
      expect(find.byIcon(Icons.mic), findsOneWidget);
    });

    testWidgets('should show speech indicator when child is speaking',
        (tester) async {
      // Arrange
      when(() => mockInteractionNotifier.state).thenReturn(
        InteractionState(
          mode: SessionMode.interactive,
          status: SessionStatus.active,
          isListening: true,
          isChildSpeaking: true,
        ),
      );

      // Act
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            interactionProvider.overrideWith(() => mockInteractionNotifier),
          ],
          child: const MaterialApp(
            home: InteractivePlaybackPage(
              storyId: 'story-123',
              storyTitle: '小兔子的冒險',
            ),
          ),
        ),
      );

      // Assert - should show active speech indicator
      expect(find.byKey(const Key('speech_indicator')), findsOneWidget);
    });

    testWidgets('should display AI response text', (tester) async {
      // Arrange
      when(() => mockInteractionNotifier.state).thenReturn(
        InteractionState(
          mode: SessionMode.interactive,
          status: SessionStatus.active,
          currentAIResponseText: '小兔子很勇敢喔！',
        ),
      );

      // Act
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            interactionProvider.overrideWith(() => mockInteractionNotifier),
          ],
          child: const MaterialApp(
            home: InteractivePlaybackPage(
              storyId: 'story-123',
              storyTitle: '小兔子的冒險',
            ),
          ),
        ),
      );

      // Assert
      expect(find.text('小兔子很勇敢喔！'), findsOneWidget);
    });

    testWidgets('should display transcript text', (tester) async {
      // Arrange
      when(() => mockInteractionNotifier.state).thenReturn(
        InteractionState(
          mode: SessionMode.interactive,
          status: SessionStatus.active,
          currentTranscript: '小兔子會不會遇到大野狼？',
        ),
      );

      // Act
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            interactionProvider.overrideWith(() => mockInteractionNotifier),
          ],
          child: const MaterialApp(
            home: InteractivePlaybackPage(
              storyId: 'story-123',
              storyTitle: '小兔子的冒險',
            ),
          ),
        ),
      );

      // Assert
      expect(find.text('小兔子會不會遇到大野狼？'), findsOneWidget);
    });
  });

  group('InteractivePlaybackPage - User Interactions', () {
    testWidgets('should toggle mode when mode toggle is tapped',
        (tester) async {
      // Arrange
      when(() => mockInteractionNotifier.state).thenReturn(
        InteractionState(
          mode: SessionMode.passive,
          status: SessionStatus.active,
        ),
      );
      when(() => mockInteractionNotifier.switchMode(any()))
          .thenAnswer((_) async {});

      // Act
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            interactionProvider.overrideWith(() => mockInteractionNotifier),
          ],
          child: const MaterialApp(
            home: InteractivePlaybackPage(
              storyId: 'story-123',
              storyTitle: '小兔子的冒險',
            ),
          ),
        ),
      );

      // Tap the mode toggle
      await tester.tap(find.byType(ModeToggle));
      await tester.pumpAndSettle();

      // Assert
      verify(() => mockInteractionNotifier.switchMode(SessionMode.interactive))
          .called(1);
    });

    testWidgets('should pause story when pause button is tapped',
        (tester) async {
      // Arrange
      when(() => mockInteractionNotifier.state).thenReturn(
        InteractionState(
          mode: SessionMode.interactive,
          status: SessionStatus.active,
          isPlaying: true,
        ),
      );
      when(() => mockInteractionNotifier.pause()).thenAnswer((_) async {});

      // Act
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            interactionProvider.overrideWith(() => mockInteractionNotifier),
          ],
          child: const MaterialApp(
            home: InteractivePlaybackPage(
              storyId: 'story-123',
              storyTitle: '小兔子的冒險',
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.pause));
      await tester.pumpAndSettle();

      // Assert
      verify(() => mockInteractionNotifier.pause()).called(1);
    });

    testWidgets('should end session when back button is pressed',
        (tester) async {
      // Arrange
      when(() => mockInteractionNotifier.state).thenReturn(
        InteractionState(
          mode: SessionMode.interactive,
          status: SessionStatus.active,
        ),
      );
      when(() => mockInteractionNotifier.endSession()).thenAnswer((_) async {});

      // Act
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            interactionProvider.overrideWith(() => mockInteractionNotifier),
          ],
          child: const MaterialApp(
            home: InteractivePlaybackPage(
              storyId: 'story-123',
              storyTitle: '小兔子的冒險',
            ),
          ),
        ),
      );

      // Tap back button
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // Should show confirmation dialog
      expect(find.text('確定要結束互動嗎？'), findsOneWidget);

      // Confirm
      await tester.tap(find.text('結束'));
      await tester.pumpAndSettle();

      // Assert
      verify(() => mockInteractionNotifier.endSession()).called(1);
    });
  });

  group('InteractivePlaybackPage - Error States', () {
    testWidgets('should display error message on error', (tester) async {
      // Arrange
      when(() => mockInteractionNotifier.state).thenReturn(
        InteractionState(
          mode: SessionMode.interactive,
          status: SessionStatus.error,
          errorMessage: '語音辨識服務暫時無法使用',
        ),
      );

      // Act
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            interactionProvider.overrideWith(() => mockInteractionNotifier),
          ],
          child: const MaterialApp(
            home: InteractivePlaybackPage(
              storyId: 'story-123',
              storyTitle: '小兔子的冒險',
            ),
          ),
        ),
      );

      // Assert
      expect(find.text('語音辨識服務暫時無法使用'), findsOneWidget);
    });

    testWidgets('should show retry button on recoverable error',
        (tester) async {
      // Arrange
      when(() => mockInteractionNotifier.state).thenReturn(
        InteractionState(
          mode: SessionMode.interactive,
          status: SessionStatus.error,
          errorMessage: '連線中斷，請重試',
          isRecoverableError: true,
        ),
      );
      when(() => mockInteractionNotifier.retry()).thenAnswer((_) async {});

      // Act
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            interactionProvider.overrideWith(() => mockInteractionNotifier),
          ],
          child: const MaterialApp(
            home: InteractivePlaybackPage(
              storyId: 'story-123',
              storyTitle: '小兔子的冒險',
            ),
          ),
        ),
      );

      expect(find.text('重試'), findsOneWidget);

      await tester.tap(find.text('重試'));
      await tester.pumpAndSettle();

      // Assert
      verify(() => mockInteractionNotifier.retry()).called(1);
    });
  });

  group('InteractivePlaybackPage - Loading States', () {
    testWidgets('should display loading indicator during initialization',
        (tester) async {
      // Arrange
      when(() => mockInteractionNotifier.state).thenReturn(
        const InteractionState(
          isLoading: true,
        ),
      );

      // Act
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            interactionProvider.overrideWith(() => mockInteractionNotifier),
          ],
          child: const MaterialApp(
            home: InteractivePlaybackPage(
              storyId: 'story-123',
              storyTitle: '小兔子的冒險',
            ),
          ),
        ),
      );

      // Assert
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should show AI thinking indicator when waiting for response',
        (tester) async {
      // Arrange
      when(() => mockInteractionNotifier.state).thenReturn(
        InteractionState(
          mode: SessionMode.interactive,
          status: SessionStatus.active,
          isWaitingForAIResponse: true,
        ),
      );

      // Act
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            interactionProvider.overrideWith(() => mockInteractionNotifier),
          ],
          child: const MaterialApp(
            home: InteractivePlaybackPage(
              storyId: 'story-123',
              storyTitle: '小兔子的冒險',
            ),
          ),
        ),
      );

      // Assert
      expect(find.text('AI 正在思考...'), findsOneWidget);
    });
  });
}
