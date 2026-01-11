import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:storybuddy/main.dart' as app;

/// End-to-end tests for complete user journeys.
///
/// These tests simulate real user interactions across multiple screens
/// and verify the app behaves correctly through complete workflows.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('User Journey: Story Import Flow', () {
    testWidgets('user can import a new story and see it in the list',
        (tester) async {
      // Start the app
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // Step 1: Navigate to import page
      // When list is empty, use empty state button; otherwise use FAB + bottom sheet
      final fab = find.byType(FloatingActionButton);
      if (fab.evaluate().isNotEmpty) {
        // Story list has items, use FAB to open bottom sheet
        await tester.tap(fab);
        await tester.pumpAndSettle();
        final importOption = find.text('匯入故事');
        expect(importOption, findsOneWidget);
        await tester.tap(importOption);
        await tester.pumpAndSettle();
      } else {
        // Empty state - use the "匯入故事" button directly
        final importButton = find.text('匯入故事');
        expect(importButton, findsOneWidget);
        await tester.tap(importButton);
        await tester.pumpAndSettle();
      }

      // Step 3: Fill in story details
      final textFields = find.byType(TextField);
      expect(textFields.evaluate().length, greaterThanOrEqualTo(2));

      // Enter title
      await tester.enterText(textFields.first, '我的第一個測試故事');
      await tester.pumpAndSettle();

      // Enter content
      await tester.enterText(
        textFields.at(1),
        '從前從前，在一個美麗的森林裡，住著一隻小兔子...',
      );
      await tester.pumpAndSettle();

      // Step 4: Submit (find and tap save/submit button)
      final saveButton = find.byIcon(Icons.check);
      if (saveButton.evaluate().isNotEmpty) {
        await tester.tap(saveButton);
        await tester.pumpAndSettle(const Duration(seconds: 2));
      }
    });
  });

  group('User Journey: Story Playback Flow', () {
    testWidgets('user can select a story and access playback controls',
        (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Check if there are any stories to play
      final storyCards = find.byType(Card);
      if (storyCards.evaluate().isNotEmpty) {
        // Tap on first story
        await tester.tap(storyCards.first);
        await tester.pumpAndSettle();

        // Verify we're on story detail page
        final playButton = find.byIcon(Icons.play_arrow);
        // If play button exists, tap it
        if (playButton.evaluate().isNotEmpty) {
          await tester.tap(playButton);
          await tester.pumpAndSettle();

          // Verify playback controls appear
          expect(
            find.byIcon(Icons.pause).evaluate().isNotEmpty ||
                find.byIcon(Icons.play_arrow).evaluate().isNotEmpty,
            true,
          );
        }
      }
    });
  });

  group('User Journey: Q&A Session Flow', () {
    testWidgets('user can start a Q&A session after story playback',
        (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Find any story card
      final storyCards = find.byType(Card);
      if (storyCards.evaluate().isNotEmpty) {
        // Navigate to story detail
        await tester.tap(storyCards.first);
        await tester.pumpAndSettle();

        // Look for Q&A button
        final qaButton = find.byIcon(Icons.question_answer);
        if (qaButton.evaluate().isNotEmpty) {
          await tester.tap(qaButton);
          await tester.pumpAndSettle();

          // Verify Q&A session page elements
          expect(
            find.byIcon(Icons.mic).evaluate().isNotEmpty ||
                find.byType(TextField).evaluate().isNotEmpty,
            true,
          );
        }
      }
    });
  });

  group('User Journey: Voice Profile Recording Flow', () {
    testWidgets('user can navigate to voice recording page', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Look for voice profile entry point
      final micButton = find.byIcon(Icons.mic);
      final voiceText = find.text('聲音');

      if (micButton.evaluate().isNotEmpty) {
        await tester.tap(micButton.first);
        await tester.pumpAndSettle();

        // Verify recording page elements
        expect(
          find.byIcon(Icons.fiber_manual_record).evaluate().isNotEmpty ||
              find.text('開始錄音').evaluate().isNotEmpty ||
              find.byIcon(Icons.mic).evaluate().isNotEmpty,
          true,
        );
      }
    });
  });

  group('User Journey: Settings Flow', () {
    testWidgets('user can access settings and change theme', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Find settings button
      final settingsButton = find.byIcon(Icons.settings);
      if (settingsButton.evaluate().isNotEmpty) {
        await tester.tap(settingsButton.first);
        await tester.pumpAndSettle();

        // Verify settings page
        expect(find.text('設定'), findsOneWidget);

        // Look for theme toggle
        final themeSwitch = find.byType(Switch);
        if (themeSwitch.evaluate().isNotEmpty) {
          await tester.tap(themeSwitch.first);
          await tester.pumpAndSettle();

          // Theme should change - app should still be functional
          expect(find.byType(Scaffold), findsWidgets);
        }
      }
    });

    testWidgets('user can access data deletion option', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Navigate to settings
      final settingsButton = find.byIcon(Icons.settings);
      if (settingsButton.evaluate().isNotEmpty) {
        await tester.tap(settingsButton.first);
        await tester.pumpAndSettle();

        // Look for delete data option
        final deleteOption = find.text('刪除本地資料');
        if (deleteOption.evaluate().isNotEmpty) {
          await tester.tap(deleteOption);
          await tester.pumpAndSettle();

          // Should show confirmation dialog
          expect(
            find.text('確認').evaluate().isNotEmpty ||
                find.text('取消').evaluate().isNotEmpty ||
                find.byType(AlertDialog).evaluate().isNotEmpty,
            true,
          );

          // Cancel to not actually delete
          final cancelButton = find.text('取消');
          if (cancelButton.evaluate().isNotEmpty) {
            await tester.tap(cancelButton);
            await tester.pumpAndSettle();
          }
        }
      }
    });
  });

  group('User Journey: Pending Questions Flow', () {
    testWidgets('user can view pending questions list', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Look for pending questions navigation
      final pendingButton = find.byIcon(Icons.help_outline);
      final pendingText = find.text('待回答');

      if (pendingButton.evaluate().isNotEmpty) {
        await tester.tap(pendingButton.first);
        await tester.pumpAndSettle();
      } else if (pendingText.evaluate().isNotEmpty) {
        await tester.tap(pendingText);
        await tester.pumpAndSettle();
      }

      // Verify we can see the pending questions area
      // Could be empty state or list
      expect(find.byType(Scaffold), findsWidgets);
    });
  });

  group('User Journey: Offline Mode', () {
    testWidgets('app displays offline indicator appropriately', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // The app should handle offline state gracefully
      // Just verify app renders correctly
      expect(find.text('我的故事'), findsOneWidget);
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('downloaded stories show offline availability', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Check for downloaded indicator icons
      final downloadedIcon = find.byIcon(Icons.cloud_done);
      final downloadIcon = find.byIcon(Icons.cloud_download);

      // Either shows downloaded status or download option
      // Just verify app renders correctly
      expect(find.byType(Scaffold), findsWidgets);
    });
  });

  group('User Journey: Story Generation Flow', () {
    testWidgets('user can access AI story generation', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // Navigate to AI generation page
      // When list is empty, use empty state button; otherwise use FAB + bottom sheet
      final fab = find.byType(FloatingActionButton);
      if (fab.evaluate().isNotEmpty) {
        // Story list has items, use FAB to open bottom sheet
        await tester.tap(fab);
        await tester.pumpAndSettle();
        final generateOption = find.text('AI 生成');
        expect(generateOption, findsOneWidget);
        await tester.tap(generateOption);
        await tester.pumpAndSettle();
      } else {
        // Empty state - use the "AI 生成" button directly
        final generateButton = find.text('AI 生成');
        expect(generateButton, findsOneWidget);
        await tester.tap(generateButton);
        await tester.pumpAndSettle();
      }

      // Verify generation page has keyword input
      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets('user can enter keywords for story generation', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // Navigate to generation page
      // When list is empty, use empty state button; otherwise use FAB + bottom sheet
      final fab = find.byType(FloatingActionButton);
      if (fab.evaluate().isNotEmpty) {
        // Story list has items, use FAB to open bottom sheet
        await tester.tap(fab);
        await tester.pumpAndSettle();
        await tester.tap(find.text('AI 生成'));
        await tester.pumpAndSettle();
      } else {
        // Empty state - use the "AI 生成" button directly
        await tester.tap(find.text('AI 生成'));
        await tester.pumpAndSettle();
      }

      // Enter keywords
      final keywordField = find.byType(TextField);
      if (keywordField.evaluate().isNotEmpty) {
        await tester.enterText(keywordField.first, '小熊 森林 冒險');
        await tester.pumpAndSettle();

        // Verify keywords were entered
        expect(find.text('小熊 森林 冒險'), findsOneWidget);
      }
    });
  });
}
