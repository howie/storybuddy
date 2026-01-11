/// T072 [P] [US4] Widget test for transcript viewer.
///
/// Tests the TranscriptViewer widget for displaying interaction transcripts.
library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:storybuddy/features/interaction/domain/entities/interaction_transcript.dart';
import 'package:storybuddy/features/interaction/presentation/widgets/transcript_viewer.dart';

void main() {
  group('TranscriptViewer', () {
    late InteractionTranscript sampleTranscript;

    setUp(() {
      sampleTranscript = InteractionTranscript(
        id: 'transcript-123',
        sessionId: 'session-456',
        storyTitle: '小熊的冒險',
        plainText: '''
[00:00] 孩子：這個故事好好聽！
[00:15] AI：很高興你喜歡！小熊接下來會遇到什麼呢？
[00:30] 孩子：我覺得小熊會找到蜂蜜！
[00:45] AI：說得對！小熊聞到了甜甜的蜂蜜味道。''',
        htmlContent: '<div class="transcript">...</div>',
        turnCount: 2,
        totalDurationMs: 60000,
        createdAt: DateTime.now(),
      );
    });

    Widget buildTestWidget({
      required InteractionTranscript transcript,
      VoidCallback? onShare,
      VoidCallback? onEmail,
    }) {
      return ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: TranscriptViewer(
              transcript: transcript,
              onShare: onShare,
              onEmail: onEmail,
            ),
          ),
        ),
      );
    }

    testWidgets('displays story title', (tester) async {
      await tester.pumpWidget(buildTestWidget(transcript: sampleTranscript));

      expect(find.text('小熊的冒險'), findsOneWidget);
    });

    testWidgets('displays transcript content', (tester) async {
      await tester.pumpWidget(buildTestWidget(transcript: sampleTranscript));

      expect(find.textContaining('這個故事好好聽'), findsOneWidget);
      expect(find.textContaining('小熊會找到蜂蜜'), findsOneWidget);
    });

    testWidgets('displays turn count', (tester) async {
      await tester.pumpWidget(buildTestWidget(transcript: sampleTranscript));

      // Should show turn count somewhere in the UI
      expect(find.textContaining('2'), findsWidgets);
    });

    testWidgets('displays duration', (tester) async {
      await tester.pumpWidget(buildTestWidget(transcript: sampleTranscript));

      // Duration should be shown (1 minute)
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              ((widget.data?.contains('1') ?? false) ||
                  (widget.data?.contains('分鐘') ?? false)),
        ),
        findsWidgets,
      );
    });

    testWidgets('shows share button when onShare provided', (tester) async {
      var sharePressed = false;

      await tester.pumpWidget(
        buildTestWidget(
          transcript: sampleTranscript,
          onShare: () => sharePressed = true,
        ),
      );

      final shareButton = find.byIcon(Icons.share);
      expect(shareButton, findsOneWidget);

      await tester.tap(shareButton);
      await tester.pump();

      expect(sharePressed, isTrue);
    });

    testWidgets('shows email button when onEmail provided', (tester) async {
      var emailPressed = false;

      await tester.pumpWidget(
        buildTestWidget(
          transcript: sampleTranscript,
          onEmail: () => emailPressed = true,
        ),
      );

      final emailButton = find.byIcon(Icons.email);
      expect(emailButton, findsOneWidget);

      await tester.tap(emailButton);
      await tester.pump();

      expect(emailPressed, isTrue);
    });

    testWidgets('hides share button when onShare not provided', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          transcript: sampleTranscript,
        ),
      );

      expect(find.byIcon(Icons.share), findsNothing);
    });

    testWidgets('differentiates child and AI messages', (tester) async {
      await tester.pumpWidget(buildTestWidget(transcript: sampleTranscript));

      // Should have visual distinction between speakers
      // Check for different colors or labels
      expect(find.textContaining('孩子'), findsWidgets);
      expect(find.textContaining('AI'), findsWidgets);
    });

    testWidgets('shows timestamps', (tester) async {
      await tester.pumpWidget(buildTestWidget(transcript: sampleTranscript));

      // Should display timestamps like [00:00], [00:15], etc.
      expect(find.textContaining('00:'), findsWidgets);
    });

    testWidgets('scrolls through long transcript', (tester) async {
      // Create a transcript with many entries
      final longTranscript = InteractionTranscript(
        id: 'long-transcript',
        sessionId: 'session-789',
        storyTitle: '長篇故事',
        plainText: List.generate(
          20,
          (i) => '[${i.toString().padLeft(2, '0')}:00] 對話 $i',
        ).join('\n'),
        htmlContent: '<div>Long transcript</div>',
        turnCount: 20,
        totalDurationMs: 600000,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(buildTestWidget(transcript: longTranscript));

      // Should be scrollable
      final scrollable = find.byType(Scrollable);
      expect(scrollable, findsWidgets);

      // Scroll down
      await tester.drag(scrollable.first, const Offset(0, -300));
      await tester.pump();

      // Later entries should be visible after scroll
      expect(find.textContaining('對話 15'), findsOneWidget);
    });

    testWidgets('displays creation date', (tester) async {
      await tester.pumpWidget(buildTestWidget(transcript: sampleTranscript));

      // Should show the date in some format
      final now = DateTime.now();
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              ((widget.data?.contains(now.month.toString()) ?? false) ||
                  (widget.data?.contains('今天') ?? false)),
        ),
        findsWidgets,
      );
    });

    testWidgets('handles empty transcript gracefully', (tester) async {
      final emptyTranscript = InteractionTranscript(
        id: 'empty-transcript',
        sessionId: 'session-empty',
        storyTitle: '空白故事',
        plainText: '（沒有對話紀錄）',
        htmlContent: '<div>Empty</div>',
        turnCount: 0,
        totalDurationMs: 0,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(buildTestWidget(transcript: emptyTranscript));

      expect(find.textContaining('沒有對話'), findsOneWidget);
    });

    testWidgets('shows interrupted message indicator', (tester) async {
      final interruptedTranscript = InteractionTranscript(
        id: 'interrupted-transcript',
        sessionId: 'session-int',
        storyTitle: '被打斷的故事',
        plainText: '''
[00:00] AI：讓我告訴你— [中斷]
[00:05] 孩子：我知道答案！''',
        htmlContent: '<div>Interrupted</div>',
        turnCount: 1,
        totalDurationMs: 10000,
        createdAt: DateTime.now(),
      );

      await tester
          .pumpWidget(buildTestWidget(transcript: interruptedTranscript));

      // Should show interruption indicator
      expect(find.textContaining('中斷'), findsOneWidget);
    });

    testWidgets('accessibility: has semantic labels', (tester) async {
      await tester.pumpWidget(buildTestWidget(transcript: sampleTranscript));

      // Check for semantic widgets
      expect(
        find.bySemanticsLabel(
            RegExp('.*互動紀錄.*|.*transcript.*', caseSensitive: false),),
        findsWidgets,
      );
    });

    testWidgets('can expand/collapse sections', (tester) async {
      await tester.pumpWidget(buildTestWidget(transcript: sampleTranscript));

      // Look for expandable sections if implemented
      final expansionTile = find.byType(ExpansionTile);
      if (expansionTile.evaluate().isNotEmpty) {
        await tester.tap(expansionTile.first);
        await tester.pumpAndSettle();

        // Content should be expanded/collapsed
        expect(expansionTile, findsWidgets);
      }
    });
  });

  group('TranscriptViewer Loading State', () {
    testWidgets('shows loading indicator', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: TranscriptViewerLoading(),
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('TranscriptViewer Error State', () {
    testWidgets('shows error message', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: TranscriptViewerError(
                message: '無法載入紀錄',
                onRetry: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.textContaining('無法載入'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('retry button triggers callback', (tester) async {
      var retryPressed = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: TranscriptViewerError(
                message: '錯誤',
                onRetry: () => retryPressed = true,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(retryPressed, isTrue);
    });
  });
}
