import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';


/// Helper functions for creating test widgets.
class TestHelpers {
  TestHelpers._();

  /// Wraps a widget in MaterialApp and ProviderScope for testing.
  static Widget createTestApp({
    required Widget child,
    List<Override>? overrides,
    ThemeMode? themeMode,
    String? initialRoute,
  }) {
    return ProviderScope(
      overrides: overrides ?? [],
      child: MaterialApp(
        home: child,
        themeMode: themeMode ?? ThemeMode.light,
        theme: ThemeData.light(useMaterial3: true),
        darkTheme: ThemeData.dark(useMaterial3: true),
      ),
    );
  }

  /// Wraps a widget in MaterialApp with router for testing navigation.
  static Widget createTestAppWithRouter({
    required Widget child,
    List<Override>? overrides,
    String? initialRoute,
  }) {
    return ProviderScope(
      overrides: overrides ?? [],
      child: MaterialApp(
        home: child,
        theme: ThemeData.light(useMaterial3: true),
        onGenerateRoute: (settings) {
          // Simple route handling for tests
          return MaterialPageRoute(builder: (_) => child);
        },
      ),
    );
  }

  /// Pumps widget and waits for all animations to settle.
  static Future<void> pumpAndSettle(
    WidgetTester tester,
    Widget widget, {
    Duration? duration,
  }) async {
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle(duration ?? const Duration(milliseconds: 100));
  }

  /// Finds a widget by key and taps it.
  static Future<void> tapByKey(WidgetTester tester, Key key) async {
    final finder = find.byKey(key);
    expect(finder, findsOneWidget);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  /// Finds a widget by text and taps it.
  static Future<void> tapByText(WidgetTester tester, String text) async {
    final finder = find.text(text);
    expect(finder, findsOneWidget);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  /// Finds a widget by icon and taps it.
  static Future<void> tapByIcon(WidgetTester tester, IconData icon) async {
    final finder = find.byIcon(icon);
    expect(finder, findsOneWidget);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  /// Enters text into a TextField found by key.
  static Future<void> enterTextByKey(
    WidgetTester tester,
    Key key,
    String text,
  ) async {
    final finder = find.byKey(key);
    expect(finder, findsOneWidget);
    await tester.enterText(finder, text);
    await tester.pumpAndSettle();
  }

  /// Scrolls until a widget is visible.
  static Future<void> scrollUntilVisible(
    WidgetTester tester,
    Finder finder, {
    double delta = -100,
    Finder? scrollable,
  }) async {
    await tester.scrollUntilVisible(
      finder,
      delta,
      scrollable: scrollable ?? find.byType(ListView),
    );
    await tester.pumpAndSettle();
  }

  /// Performs a pull-to-refresh gesture.
  static Future<void> pullToRefresh(WidgetTester tester) async {
    final listView = find.byType(ListView);
    if (listView.evaluate().isNotEmpty) {
      await tester.fling(listView.first, const Offset(0, 300), 1000);
      await tester.pumpAndSettle();
    }
  }

  /// Verifies that a snackbar with specific text is shown.
  static void expectSnackBar(String text) {
    expect(find.text(text), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  }

  /// Verifies that a dialog is shown.
  static void expectDialog() {
    expect(find.byType(AlertDialog), findsOneWidget);
  }

  /// Dismisses a dialog by tapping the cancel button.
  static Future<void> dismissDialog(WidgetTester tester) async {
    final cancelButton = find.text('取消');
    if (cancelButton.evaluate().isNotEmpty) {
      await tester.tap(cancelButton);
      await tester.pumpAndSettle();
    } else {
      // Try tapping outside the dialog
      await tester.tapAt(const Offset(0, 0));
      await tester.pumpAndSettle();
    }
  }

  /// Confirms a dialog by tapping the confirm button.
  static Future<void> confirmDialog(WidgetTester tester) async {
    final confirmButton = find.text('確認');
    if (confirmButton.evaluate().isNotEmpty) {
      await tester.tap(confirmButton);
      await tester.pumpAndSettle();
    }
  }
}

/// Extension methods for WidgetTester to simplify common operations.
extension WidgetTesterExtensions on WidgetTester {
  /// Pumps widget and waits for animations.
  Future<void> pumpApp(Widget widget) async {
    await pumpWidget(TestHelpers.createTestApp(child: widget));
    await pumpAndSettle();
  }

  /// Taps a widget found by text.
  Future<void> tapText(String text) async {
    await tap(find.text(text));
    await pumpAndSettle();
  }

  /// Taps a widget found by icon.
  Future<void> tapIcon(IconData icon) async {
    await tap(find.byIcon(icon));
    await pumpAndSettle();
  }

  /// Enters text into the first TextField.
  Future<void> enterTextInField(String text) async {
    await enterText(find.byType(TextField).first, text);
    await pumpAndSettle();
  }
}
