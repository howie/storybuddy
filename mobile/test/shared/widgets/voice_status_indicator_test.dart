import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storybuddy/core/database/enums.dart';
import 'package:storybuddy/shared/widgets/voice_status_indicator.dart';

void main() {
  group('VoiceStatusIndicator', () {
    Widget buildTestWidget(VoiceProfileStatus? status) {
      return MaterialApp(
        home: Scaffold(
          body: VoiceStatusIndicator(status: status),
        ),
      );
    }

    testWidgets('shows "尚未錄製" when status is null', (tester) async {
      await tester.pumpWidget(buildTestWidget(null));

      expect(find.text('尚未錄製'), findsOneWidget);
      expect(find.byIcon(Icons.mic_off), findsOneWidget);
    });

    testWidgets('shows "準備中" when status is pending', (tester) async {
      await tester.pumpWidget(buildTestWidget(VoiceProfileStatus.pending));

      expect(find.text('準備中'), findsOneWidget);
      expect(find.byIcon(Icons.hourglass_empty), findsOneWidget);
    });

    testWidgets('shows "處理中" when status is processing', (tester) async {
      await tester.pumpWidget(buildTestWidget(VoiceProfileStatus.processing));

      expect(find.text('處理中'), findsOneWidget);
      expect(find.byIcon(Icons.sync), findsOneWidget);
    });

    testWidgets('shows "已就緒" when status is ready', (tester) async {
      await tester.pumpWidget(buildTestWidget(VoiceProfileStatus.ready));

      expect(find.text('已就緒'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('shows "處理失敗" when status is failed', (tester) async {
      await tester.pumpWidget(buildTestWidget(VoiceProfileStatus.failed));

      expect(find.text('處理失敗'), findsOneWidget);
      expect(find.byIcon(Icons.error), findsOneWidget);
    });

    testWidgets('uses correct colors for each status', (tester) async {
      // Test grey for null status
      await tester.pumpWidget(buildTestWidget(null));
      var icon = tester.widget<Icon>(find.byIcon(Icons.mic_off));
      expect(icon.color, Colors.grey);

      // Test orange for pending
      await tester.pumpWidget(buildTestWidget(VoiceProfileStatus.pending));
      icon = tester.widget<Icon>(find.byIcon(Icons.hourglass_empty));
      expect(icon.color, Colors.orange);

      // Test orange for processing
      await tester.pumpWidget(buildTestWidget(VoiceProfileStatus.processing));
      icon = tester.widget<Icon>(find.byIcon(Icons.sync));
      expect(icon.color, Colors.orange);

      // Test green for ready
      await tester.pumpWidget(buildTestWidget(VoiceProfileStatus.ready));
      icon = tester.widget<Icon>(find.byIcon(Icons.check_circle));
      expect(icon.color, Colors.green);

      // Test red for failed
      await tester.pumpWidget(buildTestWidget(VoiceProfileStatus.failed));
      icon = tester.widget<Icon>(find.byIcon(Icons.error));
      expect(icon.color, Colors.red);
    });

    testWidgets('renders as a compact row', (tester) async {
      await tester.pumpWidget(buildTestWidget(VoiceProfileStatus.ready));

      // Should find a Row containing the icon and text
      expect(find.byType(Row), findsWidgets);
    });
  });
}
