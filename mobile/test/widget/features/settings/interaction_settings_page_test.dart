import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:storybuddy/features/interaction/domain/entities/interaction_settings.dart';
import 'package:storybuddy/features/interaction/presentation/pages/interaction_settings_page.dart';
import 'package:storybuddy/features/interaction/presentation/providers/interaction_settings_provider.dart';

/// T059 [P] [US3] Widget test for interaction settings page.

class MockInteractionSettingsNotifier
    extends StateNotifier<AsyncValue<InteractionSettings>>
    with Mock
    implements InteractionSettingsNotifier {
  MockInteractionSettingsNotifier() : super(const AsyncValue.loading());
}

void main() {
  group('InteractionSettingsPage', () {
    late MockInteractionSettingsNotifier mockNotifier;

    setUp(() {
      mockNotifier = MockInteractionSettingsNotifier();
    });

    Widget buildTestWidget({InteractionSettings? settings}) {
      if (settings != null) {
        mockNotifier.state = AsyncValue.data(settings);
      }

      return ProviderScope(
        overrides: [
          interactionSettingsProvider.overrideWith((ref) => mockNotifier),
        ],
        child: const MaterialApp(
          home: InteractionSettingsPage(),
        ),
      );
    }

    testWidgets('displays loading indicator while fetching settings',
        (tester) async {
      mockNotifier.state = const AsyncValue.loading();

      await tester.pumpWidget(buildTestWidget());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('displays error message when settings fail to load',
        (tester) async {
      mockNotifier.state = AsyncValue.error(
        Exception('Failed to load'),
        StackTrace.current,
      );

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.text('載入設定失敗'), findsOneWidget);
      expect(find.text('重試'), findsOneWidget);
    });

    testWidgets('displays recording toggle switch', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        settings: const InteractionSettings(
          
        ),
      ),);
      await tester.pump();

      expect(find.text('錄音設定'), findsOneWidget);
      expect(find.byType(Switch), findsWidgets);
    });

    testWidgets('recording toggle shows correct initial state - disabled',
        (tester) async {
      await tester.pumpWidget(buildTestWidget(
        settings: const InteractionSettings(
          
        ),
      ),);
      await tester.pump();

      final recordingSwitch = tester.widget<Switch>(
        find.byKey(const Key('recording_enabled_switch')),
      );
      expect(recordingSwitch.value, false);
    });

    testWidgets('recording toggle shows correct initial state - enabled',
        (tester) async {
      await tester.pumpWidget(buildTestWidget(
        settings: const InteractionSettings(
          recordingEnabled: true,
        ),
      ),);
      await tester.pump();

      final recordingSwitch = tester.widget<Switch>(
        find.byKey(const Key('recording_enabled_switch')),
      );
      expect(recordingSwitch.value, true);
    });

    testWidgets('tapping recording toggle calls updateSettings',
        (tester) async {
      await tester.pumpWidget(buildTestWidget(
        settings: const InteractionSettings(
          
        ),
      ),);
      await tester.pump();

      // Find and tap the recording switch
      await tester.tap(find.byKey(const Key('recording_enabled_switch')));
      await tester.pump();

      // Verify updateSettings was called
      verify(() => mockNotifier.updateRecordingEnabled(true)).called(1);
    });

    testWidgets('displays privacy notice for recording', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        settings: const InteractionSettings(
          
        ),
      ),);
      await tester.pump();

      // Should show privacy information
      expect(
        find.textContaining('錄音'),
        findsWidgets,
      );
    });

    testWidgets('displays retention period setting', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        settings: const InteractionSettings(
          recordingEnabled: true,
        ),
      ),);
      await tester.pump();

      expect(find.text('保留期限'), findsOneWidget);
      expect(find.text('30 天'), findsOneWidget);
    });

    testWidgets('retention period is only shown when recording is enabled',
        (tester) async {
      await tester.pumpWidget(buildTestWidget(
        settings: const InteractionSettings(
          
        ),
      ),);
      await tester.pump();

      // Retention setting should be hidden or disabled when recording is off
      expect(find.byKey(const Key('retention_days_setting')), findsNothing);
    });

    testWidgets('can change retention period', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        settings: const InteractionSettings(
          recordingEnabled: true,
        ),
      ),);
      await tester.pump();

      // Tap retention setting
      await tester.tap(find.byKey(const Key('retention_days_setting')));
      await tester.pumpAndSettle();

      // Should show options
      expect(find.text('7 天'), findsOneWidget);
      expect(find.text('14 天'), findsOneWidget);
      expect(find.text('30 天'), findsWidgets);

      // Select 7 days
      await tester.tap(find.text('7 天'));
      await tester.pump();

      verify(() => mockNotifier.updateRetentionDays(7)).called(1);
    });

    testWidgets('shows confirmation dialog when enabling recording',
        (tester) async {
      await tester.pumpWidget(buildTestWidget(
        settings: const InteractionSettings(
          
        ),
      ),);
      await tester.pump();

      // Tap recording switch
      await tester.tap(find.byKey(const Key('recording_enabled_switch')));
      await tester.pumpAndSettle();

      // Should show confirmation dialog
      expect(find.text('啟用錄音'), findsOneWidget);
      expect(
        find.textContaining('隱私'),
        findsWidgets,
      );
      expect(find.text('取消'), findsOneWidget);
      expect(find.text('確認'), findsOneWidget);
    });

    testWidgets('confirmation dialog can be cancelled', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        settings: const InteractionSettings(
          
        ),
      ),);
      await tester.pump();

      // Tap recording switch
      await tester.tap(find.byKey(const Key('recording_enabled_switch')));
      await tester.pumpAndSettle();

      // Tap cancel
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      // Recording should still be disabled
      final recordingSwitch = tester.widget<Switch>(
        find.byKey(const Key('recording_enabled_switch')),
      );
      expect(recordingSwitch.value, false);
    });

    testWidgets('confirmation dialog confirms enabling', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        settings: const InteractionSettings(
          
        ),
      ),);
      await tester.pump();

      // Tap recording switch
      await tester.tap(find.byKey(const Key('recording_enabled_switch')));
      await tester.pumpAndSettle();

      // Tap confirm
      await tester.tap(find.text('確認'));
      await tester.pump();

      verify(() => mockNotifier.updateRecordingEnabled(true)).called(1);
    });

    testWidgets('displays auto-transcribe toggle', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        settings: const InteractionSettings(
          recordingEnabled: true,
        ),
      ),);
      await tester.pump();

      expect(find.text('自動轉寫'), findsOneWidget);
      expect(find.byKey(const Key('auto_transcribe_switch')), findsOneWidget);
    });

    testWidgets('shows delete all recordings button when recordings exist',
        (tester) async {
      await tester.pumpWidget(buildTestWidget(
        settings: const InteractionSettings(
          recordingEnabled: true,
        ),
      ),);
      await tester.pump();

      expect(find.text('刪除所有錄音'), findsOneWidget);
    });

    testWidgets('delete all recordings shows confirmation dialog',
        (tester) async {
      await tester.pumpWidget(buildTestWidget(
        settings: const InteractionSettings(
          recordingEnabled: true,
        ),
      ),);
      await tester.pump();

      await tester.tap(find.text('刪除所有錄音'));
      await tester.pumpAndSettle();

      expect(find.text('確認刪除'), findsOneWidget);
      expect(
        find.textContaining('無法復原'),
        findsWidgets,
      );
    });

    testWidgets('displays storage usage information', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        settings: const InteractionSettings(
          recordingEnabled: true,
        ),
      ),);
      await tester.pump();

      // Should show storage info section
      expect(find.text('儲存空間'), findsOneWidget);
    });
  });
}
