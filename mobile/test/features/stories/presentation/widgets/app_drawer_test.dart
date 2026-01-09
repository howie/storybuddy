import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:storybuddy/core/database/enums.dart';
import 'package:storybuddy/features/stories/presentation/widgets/app_drawer.dart';
import 'package:storybuddy/features/voice_profile/domain/entities/voice_profile.dart';
import 'package:storybuddy/features/voice_profile/presentation/providers/voice_profile_provider.dart';

void main() {
  group('AppDrawer', () {
    late List<String> navigatedPaths;

    setUp(() {
      navigatedPaths = [];
    });

    Widget buildTestWidget({
      List<VoiceProfile>? voiceProfiles,
      bool isLoading = false,
      Object? error,
    }) {
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              drawer: const AppDrawer(),
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  child: const Text('Open Drawer'),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/voice-profile',
            builder: (context, state) {
              navigatedPaths.add('/voice-profile');
              return const Scaffold(body: Text('Voice Profile'));
            },
          ),
          GoRoute(
            path: '/pending-questions',
            builder: (context, state) {
              navigatedPaths.add('/pending-questions');
              return const Scaffold(body: Text('Pending Questions'));
            },
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) {
              navigatedPaths.add('/settings');
              return const Scaffold(body: Text('Settings'));
            },
          ),
        ],
      );

      return ProviderScope(
        overrides: [
          voiceProfileListNotifierProvider.overrideWith(
            () => _FakeVoiceProfileListNotifier(
              profiles: voiceProfiles,
              isLoading: isLoading,
              error: error,
            ),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
        ),
      );
    }

    testWidgets('displays app title in drawer header', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.tap(find.text('Open Drawer'));
      await tester.pumpAndSettle();

      expect(find.text('StoryBuddy'), findsOneWidget);
    });

    testWidgets('displays 錄製聲音 menu item', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.tap(find.text('Open Drawer'));
      await tester.pumpAndSettle();

      expect(find.text('錄製聲音'), findsOneWidget);
      expect(find.byIcon(Icons.mic), findsOneWidget);
    });

    testWidgets('displays 待答問題 menu item', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.tap(find.text('Open Drawer'));
      await tester.pumpAndSettle();

      expect(find.text('待答問題'), findsOneWidget);
      expect(find.byIcon(Icons.question_answer), findsOneWidget);
    });

    testWidgets('displays 設定 menu item', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.tap(find.text('Open Drawer'));
      await tester.pumpAndSettle();

      expect(find.text('設定'), findsOneWidget);
      expect(find.byIcon(Icons.settings), findsOneWidget);
    });

    testWidgets('navigates to /voice-profile when 錄製聲音 is tapped',
        (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.tap(find.text('Open Drawer'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('錄製聲音'));
      await tester.pumpAndSettle();

      expect(navigatedPaths, contains('/voice-profile'));
    });

    testWidgets('navigates to /pending-questions when 待答問題 is tapped',
        (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.tap(find.text('Open Drawer'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('待答問題'));
      await tester.pumpAndSettle();

      expect(navigatedPaths, contains('/pending-questions'));
    });

    testWidgets('navigates to /settings when 設定 is tapped', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.tap(find.text('Open Drawer'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('設定'));
      await tester.pumpAndSettle();

      expect(navigatedPaths, contains('/settings'));
    });

    testWidgets('displays voice status indicator with ready status',
        (tester) async {
      final readyProfile = VoiceProfile(
        id: '1',
        parentId: 'parent1',
        name: 'Test Voice',
        status: VoiceProfileStatus.ready,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(buildTestWidget(voiceProfiles: [readyProfile]));
      await tester.tap(find.text('Open Drawer'));
      await tester.pumpAndSettle();

      expect(find.text('已就緒'), findsOneWidget);
    });

    testWidgets('displays voice status indicator with null status when no profiles',
        (tester) async {
      await tester.pumpWidget(buildTestWidget(voiceProfiles: []));
      await tester.tap(find.text('Open Drawer'));
      await tester.pumpAndSettle();

      expect(find.text('尚未錄製'), findsOneWidget);
    });

    testWidgets('displays voice status indicator with processing status',
        (tester) async {
      final processingProfile = VoiceProfile(
        id: '1',
        parentId: 'parent1',
        name: 'Test Voice',
        status: VoiceProfileStatus.processing,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester
          .pumpWidget(buildTestWidget(voiceProfiles: [processingProfile]));
      await tester.tap(find.text('Open Drawer'));
      await tester.pumpAndSettle();

      expect(find.text('處理中'), findsOneWidget);
    });
  });
}

/// Fake notifier for testing that provides controlled voice profile data.
class _FakeVoiceProfileListNotifier extends VoiceProfileListNotifier {
  _FakeVoiceProfileListNotifier({
    this.profiles,
    this.isLoading = false,
    this.error,
  });

  final List<VoiceProfile>? profiles;
  final bool isLoading;
  final Object? error;

  @override
  Future<List<VoiceProfile>> build() async {
    if (isLoading) {
      // Return empty list but keep loading state
      await Future.delayed(const Duration(hours: 1));
    }
    if (error != null) {
      throw error!;
    }
    return profiles ?? [];
  }
}
