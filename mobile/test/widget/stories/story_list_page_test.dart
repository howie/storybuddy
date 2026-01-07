import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:storybuddy/core/database/enums.dart';
import 'package:storybuddy/features/stories/domain/entities/story.dart';
import 'package:storybuddy/features/stories/presentation/widgets/story_card.dart';
import 'package:storybuddy/features/stories/presentation/widgets/story_empty_state.dart';

import '../../fixtures/test_data.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('StoryListPage Widget Tests', () {
    testWidgets('StoryCard displays story title and source', (tester) async {
      await tester.pumpWidget(
        TestHelpers.createTestApp(
          child: Scaffold(
            body: StoryCard(
              story: TestData.story1,
              onTap: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('小紅帽'), findsOneWidget);
      expect(find.text('匯入'), findsOneWidget);
    });

    testWidgets('StoryCard shows AI generated label for AI stories', (tester) async {
      await tester.pumpWidget(
        TestHelpers.createTestApp(
          child: Scaffold(
            body: StoryCard(
              story: TestData.story2,
              onTap: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('三隻小豬'), findsOneWidget);
      expect(find.text('AI 生成'), findsOneWidget);
    });

    testWidgets('StoryCard shows download icon when audio available', (tester) async {
      await tester.pumpWidget(
        TestHelpers.createTestApp(
          child: Scaffold(
            body: StoryCard(
              story: TestData.story1,
              onTap: () {},
              onDownloadTap: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.download_outlined), findsOneWidget);
    });

    testWidgets('StoryCard shows downloaded icon when story is downloaded', (tester) async {
      await tester.pumpWidget(
        TestHelpers.createTestApp(
          child: Scaffold(
            body: StoryCard(
              story: TestData.story2, // This one is downloaded
              onTap: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.offline_pin), findsOneWidget);
    });

    testWidgets('StoryCard calls onTap when tapped', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        TestHelpers.createTestApp(
          child: Scaffold(
            body: StoryCard(
              story: TestData.story1,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(StoryCard));
      await tester.pumpAndSettle();

      expect(tapped, true);
    });

    testWidgets('StoryCard shows play button when audio available', (tester) async {
      await tester.pumpWidget(
        TestHelpers.createTestApp(
          child: Scaffold(
            body: StoryCard(
              story: TestData.story1,
              onTap: () {},
              onPlayTap: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.play_circle_outline), findsOneWidget);
    });

    testWidgets('StoryEmptyState shows import and generate options', (tester) async {
      await tester.pumpWidget(
        TestHelpers.createTestApp(
          child: Scaffold(
            body: StoryEmptyState(
              onImportTap: () {},
              onGenerateTap: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('匯入故事'), findsOneWidget);
      expect(find.text('AI 生成'), findsOneWidget);
    });

    testWidgets('StoryEmptyState calls onImportTap', (tester) async {
      bool called = false;
      await tester.pumpWidget(
        TestHelpers.createTestApp(
          child: Scaffold(
            body: StoryEmptyState(
              onImportTap: () => called = true,
              onGenerateTap: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('匯入故事'));
      await tester.pumpAndSettle();

      expect(called, true);
    });

    testWidgets('StoryEmptyState calls onGenerateTap', (tester) async {
      bool called = false;
      await tester.pumpWidget(
        TestHelpers.createTestApp(
          child: Scaffold(
            body: StoryEmptyState(
              onImportTap: () {},
              onGenerateTap: () => called = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('AI 生成'));
      await tester.pumpAndSettle();

      expect(called, true);
    });
  });

  group('Story Entity Tests', () {
    test('Story hasAudio returns true when audioUrl is set', () {
      expect(TestData.story1.hasAudio, true);
    });

    test('Story hasAudio returns false when no audio', () {
      expect(TestData.storyNoAudio.hasAudio, false);
    });

    test('Story canPlayOffline returns true when downloaded', () {
      expect(TestData.story2.canPlayOffline, true);
    });

    test('Story canPlayOffline returns false when not downloaded', () {
      expect(TestData.story1.canPlayOffline, false);
    });

    test('Story isSynced returns correct value', () {
      expect(TestData.story1.isSynced, true);
      expect(TestData.storyPendingSync.isSynced, false);
    });

    test('Story hasPendingChanges returns correct value', () {
      expect(TestData.story1.hasPendingChanges, false);
      expect(TestData.storyPendingSync.hasPendingChanges, true);
    });

    test('Story sourceLabel returns correct label', () {
      expect(TestData.story1.sourceLabel, '匯入');
      expect(TestData.story2.sourceLabel, 'AI 生成');
    });
  });
}
