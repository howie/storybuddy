import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storybuddy/features/interaction/presentation/widgets/connection_status_widget.dart';

void main() {
  group('ConnectionStatusWidget', () {
    testWidgets('should show nothing when connected with no error',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ConnectionStatusWidget(
              isConnected: true,
              isReconnecting: false,
            ),
          ),
        ),
      );

      expect(find.byType(SizedBox), findsOneWidget);
      expect(find.text('正在重新連線...'), findsNothing);
      expect(find.text('連線已中斷'), findsNothing);
    });

    testWidgets('should show reconnecting banner with progress',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ConnectionStatusWidget(
              isConnected: false,
              isReconnecting: true,
              reconnectAttempts: 2,
              maxReconnectAttempts: 5,
            ),
          ),
        ),
      );

      expect(find.text('正在重新連線...'), findsOneWidget);
      expect(find.text('嘗試 2 / 5'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('should show disconnected banner with retry button',
        (tester) async {
      bool retryPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConnectionStatusWidget(
              isConnected: false,
              isReconnecting: false,
              onRetry: () => retryPressed = true,
            ),
          ),
        ),
      );

      expect(find.text('連線已中斷'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
      expect(find.text('重新連線'), findsOneWidget);

      await tester.tap(find.text('重新連線'));
      await tester.pump();

      expect(retryPressed, isTrue);
    });

    testWidgets('should show error banner with message', (tester) async {
      bool retryPressed = false;
      bool dismissPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConnectionStatusWidget(
              isConnected: false,
              isReconnecting: false,
              errorMessage: '網路連線失敗',
              onRetry: () => retryPressed = true,
              onDismiss: () => dismissPressed = true,
            ),
          ),
        ),
      );

      expect(find.text('網路連線失敗'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('重試'), findsOneWidget);

      await tester.tap(find.text('重試'));
      await tester.pump();
      expect(retryPressed, isTrue);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      expect(dismissPressed, isTrue);
    });
  });

  group('SessionLoadingOverlay', () {
    testWidgets('should show loading message with indeterminate progress',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SessionLoadingOverlay(
              message: '正在連線...',
            ),
          ),
        ),
      );

      expect(find.text('正在連線...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('should show loading message with determinate progress',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SessionLoadingOverlay(
              message: '載入中...',
              progress: 0.5,
            ),
          ),
        ),
      );

      expect(find.text('載入中...'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });
  });

  group('InteractionErrorDialog', () {
    testWidgets('should show recoverable error with retry option',
        (tester) async {
      bool retryPressed = false;
      bool dismissPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  InteractionErrorDialog.show(
                    context,
                    title: '連線錯誤',
                    message: '無法連線到伺服器',
                    isRecoverable: true,
                    onRetry: () => retryPressed = true,
                  );
                },
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('連線錯誤'), findsOneWidget);
      expect(find.text('無法連線到伺服器'), findsOneWidget);
      expect(find.text('重試'), findsOneWidget);
      expect(find.text('關閉'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);

      await tester.tap(find.text('重試'));
      await tester.pumpAndSettle();

      expect(retryPressed, isTrue);
      // Dialog should be dismissed
      expect(find.text('連線錯誤'), findsNothing);
    });

    testWidgets('should show non-recoverable error without retry',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  InteractionErrorDialog.show(
                    context,
                    title: '嚴重錯誤',
                    message: '系統發生異常',
                    isRecoverable: false,
                  );
                },
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('嚴重錯誤'), findsOneWidget);
      expect(find.text('系統發生異常'), findsOneWidget);
      expect(find.byIcon(Icons.error_rounded), findsOneWidget);
      // Retry button should not appear for non-recoverable errors
      expect(find.byType(FilledButton), findsNothing);
    });
  });
}
