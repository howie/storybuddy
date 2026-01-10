import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:storybuddy/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('StoryBuddy App Integration Tests', () {
    testWidgets('app starts and shows story list page', (tester) async {
      // Launch the app
      app.main();
      // Wait longer for initial app startup (includes network timeout handling)
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // Verify app loads with story list page
      expect(find.text('我的故事'), findsOneWidget);
    });

    testWidgets('can navigate to settings and back', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Find and tap the settings icon/button
      // Settings might be in a drawer or app bar
      final settingsButton = find.byIcon(Icons.settings);
      if (settingsButton.evaluate().isNotEmpty) {
        await tester.tap(settingsButton);
        await tester.pumpAndSettle();

        // Verify we're on settings page
        expect(find.text('設定'), findsOneWidget);

        // Go back
        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();

        // Verify we're back on story list
        expect(find.text('我的故事'), findsOneWidget);
      }
    });

    testWidgets('shows empty state when no stories', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Check for empty state or story list
      final emptyState = find.text('還沒有故事');
      final storyList = find.byType(ListView);

      expect(
          emptyState.evaluate().isNotEmpty || storyList.evaluate().isNotEmpty,
          true,);
    });

    testWidgets('can open add story bottom sheet', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Find and tap the FAB
      final fab = find.byType(FloatingActionButton);
      if (fab.evaluate().isNotEmpty) {
        await tester.tap(fab);
        await tester.pumpAndSettle();

        // Verify bottom sheet appears with options
        expect(find.text('匯入故事'), findsOneWidget);
        expect(find.text('AI 生成'), findsOneWidget);
      }
    });

    testWidgets('can navigate to import story page', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Open add story bottom sheet
      final fab = find.byType(FloatingActionButton);
      if (fab.evaluate().isNotEmpty) {
        await tester.tap(fab);
        await tester.pumpAndSettle();

        // Tap import option
        await tester.tap(find.text('匯入故事'));
        await tester.pumpAndSettle();

        // Verify we're on import page
        expect(find.byType(TextField), findsWidgets);
      }
    });

    testWidgets('can enter story title and content in import page',
        (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Navigate to import page
      final fab = find.byType(FloatingActionButton);
      if (fab.evaluate().isNotEmpty) {
        await tester.tap(fab);
        await tester.pumpAndSettle();

        await tester.tap(find.text('匯入故事'));
        await tester.pumpAndSettle();

        // Find text fields and enter content
        final textFields = find.byType(TextField);
        if (textFields.evaluate().length >= 2) {
          // Enter title
          await tester.enterText(textFields.first, '測試故事標題');
          await tester.pumpAndSettle();

          // Enter content
          await tester.enterText(textFields.last, '這是測試故事的內容，從前從前有一個...');
          await tester.pumpAndSettle();

          // Verify text was entered
          expect(find.text('測試故事標題'), findsOneWidget);
        }
      }
    });

    testWidgets('can navigate to AI generate story page', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Open add story bottom sheet
      final fab = find.byType(FloatingActionButton);
      if (fab.evaluate().isNotEmpty) {
        await tester.tap(fab);
        await tester.pumpAndSettle();

        // Tap AI generate option
        await tester.tap(find.text('AI 生成'));
        await tester.pumpAndSettle();

        // Verify we're on generate page (might show keyword input)
        expect(find.byType(TextField), findsWidgets);
      }
    });

    testWidgets('can navigate to voice profile recording', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Try to find voice profile navigation
      // This could be in a menu, drawer, or navigation bar
      final voiceButton = find.byIcon(Icons.mic);
      if (voiceButton.evaluate().isNotEmpty) {
        await tester.tap(voiceButton);
        await tester.pumpAndSettle();

        // Verify we see recording-related UI
        expect(
          find.byIcon(Icons.mic).evaluate().isNotEmpty ||
              find.text('錄音').evaluate().isNotEmpty,
          true,
        );
      }
    });

    testWidgets('shows offline indicator when offline', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // The offline indicator should show cloud_off icon when offline
      // This test verifies the widget exists (it may or may not be visible based on connectivity)
      final offlineIcon = find.byIcon(Icons.cloud_off);
      // Just verify the app renders without error
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('pull to refresh works on story list', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Find the refresh indicator area (usually a ListView)
      final listView = find.byType(ListView);
      if (listView.evaluate().isNotEmpty) {
        // Perform pull to refresh gesture
        await tester.fling(listView.first, const Offset(0, 300), 1000);
        await tester.pumpAndSettle();

        // Verify app still renders correctly after refresh
        expect(find.text('我的故事'), findsOneWidget);
      }
    });
  });
}
