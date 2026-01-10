import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storybuddy/features/playback/domain/entities/story_playback.dart';
import 'package:storybuddy/features/playback/presentation/widgets/playback_controls.dart';

import '../../helpers/test_helpers.dart';

void main() {
  group('PlaybackControls', () {
    testWidgets('shows play icon when not playing', (tester) async {
      await tester.pumpWidget(
        TestHelpers.createTestApp(
          child: Scaffold(
            body: PlaybackControls(
              playbackState: const StoryPlayback(
                storyId: 'story-1',
                storyTitle: 'Test Story',
                state: PlaybackState.idle,
              ),
              onPlayPause: () {},
              onSeekBackward: () {},
              onSeekForward: () {},
              onStop: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      expect(find.byIcon(Icons.pause), findsNothing);
    });

    testWidgets('shows pause icon when playing', (tester) async {
      await tester.pumpWidget(
        TestHelpers.createTestApp(
          child: Scaffold(
            body: PlaybackControls(
              playbackState: const StoryPlayback(
                storyId: 'story-1',
                storyTitle: 'Test Story',
                state: PlaybackState.playing,
              ),
              onPlayPause: () {},
              onSeekBackward: () {},
              onSeekForward: () {},
              onStop: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.pause), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsNothing);
    });

    testWidgets('shows loading indicator when loading', (tester) async {
      await tester.pumpWidget(
        TestHelpers.createTestApp(
          child: Scaffold(
            body: PlaybackControls(
              playbackState: const StoryPlayback(
                storyId: 'story-1',
                storyTitle: 'Test Story',
                state: PlaybackState.loading,
              ),
              onPlayPause: () {},
              onSeekBackward: () {},
              onSeekForward: () {},
              onStop: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows seek backward and forward buttons', (tester) async {
      await tester.pumpWidget(
        TestHelpers.createTestApp(
          child: Scaffold(
            body: PlaybackControls(
              playbackState: const StoryPlayback(
                storyId: 'story-1',
                storyTitle: 'Test Story',
                state: PlaybackState.playing,
              ),
              onPlayPause: () {},
              onSeekBackward: () {},
              onSeekForward: () {},
              onStop: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.replay_10), findsOneWidget);
      expect(find.byIcon(Icons.forward_10), findsOneWidget);
    });

    testWidgets('shows stop button', (tester) async {
      await tester.pumpWidget(
        TestHelpers.createTestApp(
          child: Scaffold(
            body: PlaybackControls(
              playbackState: const StoryPlayback(
                storyId: 'story-1',
                storyTitle: 'Test Story',
                state: PlaybackState.playing,
              ),
              onPlayPause: () {},
              onSeekBackward: () {},
              onSeekForward: () {},
              onStop: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.stop), findsOneWidget);
    });

    testWidgets('calls onPlayPause when play/pause button tapped',
        (tester) async {
      bool called = false;
      await tester.pumpWidget(
        TestHelpers.createTestApp(
          child: Scaffold(
            body: PlaybackControls(
              playbackState: const StoryPlayback(
                storyId: 'story-1',
                storyTitle: 'Test Story',
                state: PlaybackState.playing,
              ),
              onPlayPause: () => called = true,
              onSeekBackward: () {},
              onSeekForward: () {},
              onStop: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.pause));
      await tester.pumpAndSettle();

      expect(called, true);
    });

    testWidgets('calls onSeekBackward when backward button tapped',
        (tester) async {
      bool called = false;
      await tester.pumpWidget(
        TestHelpers.createTestApp(
          child: Scaffold(
            body: PlaybackControls(
              playbackState: const StoryPlayback(
                storyId: 'story-1',
                storyTitle: 'Test Story',
                state: PlaybackState.playing,
              ),
              onPlayPause: () {},
              onSeekBackward: () => called = true,
              onSeekForward: () {},
              onStop: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.replay_10));
      await tester.pumpAndSettle();

      expect(called, true);
    });

    testWidgets('calls onSeekForward when forward button tapped',
        (tester) async {
      bool called = false;
      await tester.pumpWidget(
        TestHelpers.createTestApp(
          child: Scaffold(
            body: PlaybackControls(
              playbackState: const StoryPlayback(
                storyId: 'story-1',
                storyTitle: 'Test Story',
                state: PlaybackState.playing,
              ),
              onPlayPause: () {},
              onSeekBackward: () {},
              onSeekForward: () => called = true,
              onStop: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.forward_10));
      await tester.pumpAndSettle();

      expect(called, true);
    });

    testWidgets('calls onStop when stop button tapped', (tester) async {
      bool called = false;
      await tester.pumpWidget(
        TestHelpers.createTestApp(
          child: Scaffold(
            body: PlaybackControls(
              playbackState: const StoryPlayback(
                storyId: 'story-1',
                storyTitle: 'Test Story',
                state: PlaybackState.playing,
              ),
              onPlayPause: () {},
              onSeekBackward: () {},
              onSeekForward: () {},
              onStop: () => called = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.stop));
      await tester.pumpAndSettle();

      expect(called, true);
    });

    testWidgets('disables seek buttons when idle', (tester) async {
      bool seekBackwardCalled = false;
      bool seekForwardCalled = false;
      await tester.pumpWidget(
        TestHelpers.createTestApp(
          child: Scaffold(
            body: PlaybackControls(
              playbackState: const StoryPlayback(
                storyId: 'story-1',
                storyTitle: 'Test Story',
                state: PlaybackState.idle,
              ),
              onPlayPause: () {},
              onSeekBackward: () => seekBackwardCalled = true,
              onSeekForward: () => seekForwardCalled = true,
              onStop: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Buttons should be disabled (IconButton's onPressed is null)
      final backwardButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.replay_10),
      );
      final forwardButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.forward_10),
      );

      expect(backwardButton.onPressed, isNull);
      expect(forwardButton.onPressed, isNull);
      expect(seekBackwardCalled, false);
      expect(seekForwardCalled, false);
    });

    testWidgets('shows speed button when onSpeedChange provided',
        (tester) async {
      await tester.pumpWidget(
        TestHelpers.createTestApp(
          child: Scaffold(
            body: PlaybackControls(
              playbackState: const StoryPlayback(
                storyId: 'story-1',
                storyTitle: 'Test Story',
                state: PlaybackState.playing,
              ),
              onPlayPause: () {},
              onSeekBackward: () {},
              onSeekForward: () {},
              onStop: () {},
              onSpeedChange: (_) {},
              currentSpeed: 1.0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1.0x'), findsOneWidget);
    });

    testWidgets('speed menu shows available speeds', (tester) async {
      await tester.pumpWidget(
        TestHelpers.createTestApp(
          child: Scaffold(
            body: PlaybackControls(
              playbackState: const StoryPlayback(
                storyId: 'story-1',
                storyTitle: 'Test Story',
                state: PlaybackState.playing,
              ),
              onPlayPause: () {},
              onSeekBackward: () {},
              onSeekForward: () {},
              onStop: () {},
              onSpeedChange: (_) {},
              currentSpeed: 1.0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap speed button to open menu
      await tester.tap(find.text('1.0x'));
      await tester.pumpAndSettle();

      // Check for speed options
      expect(find.text('0.5x'), findsOneWidget);
      expect(find.text('0.75x'), findsOneWidget);
      expect(find.text('1.25x'), findsOneWidget);
      expect(find.text('1.5x'), findsOneWidget);
      expect(find.text('2.0x'), findsOneWidget);
    });

    testWidgets('calls onSpeedChange with selected speed', (tester) async {
      double? selectedSpeed;
      await tester.pumpWidget(
        TestHelpers.createTestApp(
          child: Scaffold(
            body: PlaybackControls(
              playbackState: const StoryPlayback(
                storyId: 'story-1',
                storyTitle: 'Test Story',
                state: PlaybackState.playing,
              ),
              onPlayPause: () {},
              onSeekBackward: () {},
              onSeekForward: () {},
              onStop: () {},
              onSpeedChange: (speed) => selectedSpeed = speed,
              currentSpeed: 1.0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open menu and select 1.5x
      await tester.tap(find.text('1.0x'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1.5x'));
      await tester.pumpAndSettle();

      expect(selectedSpeed, 1.5);
    });
  });

  group('MiniPlaybackControls', () {
    testWidgets('shows play icon when not playing', (tester) async {
      await tester.pumpWidget(
        TestHelpers.createTestApp(
          child: Scaffold(
            body: MiniPlaybackControls(
              playbackState: const StoryPlayback(
                storyId: 'story-1',
                storyTitle: 'Test Story',
                state: PlaybackState.paused,
              ),
              onPlayPause: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    });

    testWidgets('shows pause icon when playing', (tester) async {
      await tester.pumpWidget(
        TestHelpers.createTestApp(
          child: Scaffold(
            body: MiniPlaybackControls(
              playbackState: const StoryPlayback(
                storyId: 'story-1',
                storyTitle: 'Test Story',
                state: PlaybackState.playing,
              ),
              onPlayPause: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.pause), findsOneWidget);
    });

    testWidgets('shows story title', (tester) async {
      await tester.pumpWidget(
        TestHelpers.createTestApp(
          child: Scaffold(
            body: MiniPlaybackControls(
              playbackState: const StoryPlayback(
                storyId: 'story-1',
                storyTitle: '小紅帽',
                state: PlaybackState.playing,
              ),
              onPlayPause: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('小紅帽'), findsOneWidget);
    });

    testWidgets('calls onPlayPause when tapped', (tester) async {
      bool called = false;
      await tester.pumpWidget(
        TestHelpers.createTestApp(
          child: Scaffold(
            body: MiniPlaybackControls(
              playbackState: const StoryPlayback(
                storyId: 'story-1',
                storyTitle: 'Test Story',
                state: PlaybackState.playing,
              ),
              onPlayPause: () => called = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.pause));
      await tester.pumpAndSettle();

      expect(called, true);
    });

    testWidgets('shows close button when onClose provided', (tester) async {
      await tester.pumpWidget(
        TestHelpers.createTestApp(
          child: Scaffold(
            body: MiniPlaybackControls(
              playbackState: const StoryPlayback(
                storyId: 'story-1',
                storyTitle: 'Test Story',
                state: PlaybackState.playing,
              ),
              onPlayPause: () {},
              onClose: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('hides close button when onClose not provided', (tester) async {
      await tester.pumpWidget(
        TestHelpers.createTestApp(
          child: Scaffold(
            body: MiniPlaybackControls(
              playbackState: const StoryPlayback(
                storyId: 'story-1',
                storyTitle: 'Test Story',
                state: PlaybackState.playing,
              ),
              onPlayPause: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.close), findsNothing);
    });

    testWidgets('calls onClose when close button tapped', (tester) async {
      bool called = false;
      await tester.pumpWidget(
        TestHelpers.createTestApp(
          child: Scaffold(
            body: MiniPlaybackControls(
              playbackState: const StoryPlayback(
                storyId: 'story-1',
                storyTitle: 'Test Story',
                state: PlaybackState.playing,
              ),
              onPlayPause: () {},
              onClose: () => called = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(called, true);
    });
  });

  group('StoryPlayback entity', () {
    test('progress returns correct value', () {
      const playback = StoryPlayback(
        storyId: 'story-1',
        storyTitle: 'Test',
        position: Duration(seconds: 30),
        duration: Duration(seconds: 120),
      );
      expect(playback.progress, 0.25);
    });

    test('progress returns 0 when duration is 0', () {
      const playback = StoryPlayback(
        storyId: 'story-1',
        storyTitle: 'Test',
        position: Duration(seconds: 30),
        duration: Duration.zero,
      );
      expect(playback.progress, 0.0);
    });

    test('progress clamps to max 1.0', () {
      const playback = StoryPlayback(
        storyId: 'story-1',
        storyTitle: 'Test',
        position: Duration(seconds: 150),
        duration: Duration(seconds: 120),
      );
      expect(playback.progress, 1.0);
    });

    test('bufferedProgress returns correct value', () {
      const playback = StoryPlayback(
        storyId: 'story-1',
        storyTitle: 'Test',
        bufferedPosition: Duration(seconds: 60),
        duration: Duration(seconds: 120),
      );
      expect(playback.bufferedProgress, 0.5);
    });

    test('isPlaying returns true when playing', () {
      const playback = StoryPlayback(
        storyId: 'story-1',
        storyTitle: 'Test',
        state: PlaybackState.playing,
      );
      expect(playback.isPlaying, true);
      expect(playback.isPaused, false);
    });

    test('isPaused returns true when paused', () {
      const playback = StoryPlayback(
        storyId: 'story-1',
        storyTitle: 'Test',
        state: PlaybackState.paused,
      );
      expect(playback.isPaused, true);
      expect(playback.isPlaying, false);
    });

    test('hasError returns true when error', () {
      const playback = StoryPlayback(
        storyId: 'story-1',
        storyTitle: 'Test',
        state: PlaybackState.error,
      );
      expect(playback.hasError, true);
    });

    test('remainingTime calculates correctly', () {
      const playback = StoryPlayback(
        storyId: 'story-1',
        storyTitle: 'Test',
        position: Duration(seconds: 30),
        duration: Duration(seconds: 120),
      );
      expect(playback.remainingTime, const Duration(seconds: 90));
    });

    test('formatDuration formats correctly', () {
      expect(StoryPlayback.formatDuration(const Duration(seconds: 0)), '00:00');
      expect(StoryPlayback.formatDuration(const Duration(seconds: 65)), '01:05');
      expect(StoryPlayback.formatDuration(const Duration(minutes: 10, seconds: 30)), '10:30');
    });

    test('formattedPosition returns correct format', () {
      const playback = StoryPlayback(
        storyId: 'story-1',
        storyTitle: 'Test',
        position: Duration(minutes: 2, seconds: 15),
      );
      expect(playback.formattedPosition, '02:15');
    });

    test('formattedDuration returns correct format', () {
      const playback = StoryPlayback(
        storyId: 'story-1',
        storyTitle: 'Test',
        duration: Duration(minutes: 5, seconds: 30),
      );
      expect(playback.formattedDuration, '05:30');
    });
  });
}
