import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/storage/secure_storage_service.dart';
import '../features/auth/presentation/providers/parent_provider.dart';
import '../features/pending_questions/presentation/pages/pending_questions_page.dart';
import '../features/playback/presentation/pages/playback_page.dart';
import '../features/qa_session/presentation/pages/qa_session_page.dart';
import '../features/settings/presentation/pages/settings_page.dart';
import '../features/stories/presentation/pages/generate_story_page.dart';
import '../features/stories/presentation/pages/import_story_page.dart';
import '../features/stories/presentation/pages/story_detail_page.dart';
import '../features/stories/presentation/pages/story_list_page.dart';
import '../features/voice_profile/presentation/pages/voice_profile_status_page.dart';
import '../features/voice_profile/presentation/pages/voice_recording_page.dart';
import '../features/voice_kits/presentation/pages/voice_selection_page.dart';
import '../features/voice_kits/presentation/pages/voice_kit_store_page.dart';
import '../features/voice_kits/presentation/pages/voice_configuration_page.dart';

/// Route names for the app.
abstract class AppRoutes {
  static const String home = '/';
  static const String storyList = '/stories';
  static const String storyDetail = '/stories/:id';
  static const String storyPlay = '/stories/:id/play';
  static const String storyImport = '/stories/import';
  static const String storyGenerate = '/stories/generate';
  static const String voiceProfile = '/voice-profile';
  static const String voiceRecording = '/voice-profile/record';
  static const String voiceStatus = '/voice-profile/status';
  static const String qaSession = '/stories/:id/qa';
  static const String pendingQuestions = '/pending-questions';
  static const String settings = '/settings';
  static const String voiceSelection = '/voices';
  static const String voiceStore = '/voices/store';
  static const String storyVoiceSettings = '/stories/:id/voices';
}

/// Provider to ensure a parent exists, creating one if needed (for development).
/// Always verifies the parent exists on the server to handle stale local IDs.
final _parentSetupProvider = FutureProvider<void>((ref) async {
  final secureStorage = ref.read(secureStorageServiceProvider);
  final parentRepository = ref.read(parentRepositoryProvider);
  const defaultEmail = 'parent@storybuddy.app';

  // Always check if parent exists on server by email (handles stale local IDs)
  final existingParent = await parentRepository.getParentByEmail(defaultEmail);

  if (existingParent != null) {
    // Parent exists on server, ensure we have the correct ID stored
    final storedId = await secureStorage.getParentId();
    if (storedId != existingParent.id) {
      await parentRepository.setCurrentParentId(existingParent.id);
      debugPrint('Updated parent ID to server ID: ${existingParent.id}');
    } else {
      debugPrint('Parent ID verified: ${existingParent.id}');
    }
  } else {
    // No parent on server, create one
    await parentRepository.createParent(
      name: 'Default Parent',
      email: defaultEmail,
    );
    final newParentId = await secureStorage.getParentId();
    debugPrint('Parent setup complete. Parent ID: $newParentId');
  }
});

/// Router provider for the app.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.storyList,
    debugLogDiagnostics: true,
    redirect: (context, state) async {
      // Check if parent exists, create one if not (for development)
      await ref.read(_parentSetupProvider.future);
      return null; // Continue to requested route
    },
    routes: [
      // Story List (Home)
      GoRoute(
        path: AppRoutes.storyList,
        name: 'storyList',
        builder: (context, state) => const StoryListPage(),
        routes: [
          // Import Story - MUST be before :id to avoid matching as story ID
          GoRoute(
            path: 'import',
            name: 'storyImport',
            builder: (context, state) => const ImportStoryPage(),
          ),
          // Generate Story - MUST be before :id to avoid matching as story ID
          GoRoute(
            path: 'generate',
            name: 'storyGenerate',
            builder: (context, state) => const GenerateStoryPage(),
          ),
          // Story Detail - parameterized route must come AFTER static routes
          GoRoute(
            path: ':id',
            name: 'storyDetail',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return StoryDetailPage(storyId: id);
            },
            routes: [
              // Story Playback
              GoRoute(
                path: 'play',
                name: 'storyPlay',
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return PlaybackPage(storyId: id);
                },
              ),
              // Q&A Session
              GoRoute(
                path: 'qa',
                name: 'qaSession',
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return QASessionPage(storyId: id);
                },
              ),
              // Voice Settings
              GoRoute(
                path: 'voices',
                name: 'storyVoiceSettings',
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return VoiceConfigurationPage(storyId: id);
                },
              ),
            ],
          ),
        ],
      ),
      // Voice Profile
      GoRoute(
        path: AppRoutes.voiceProfile,
        name: 'voiceProfile',
        builder: (context, state) => const VoiceRecordingPage(),
        routes: [
          // Voice Recording
          GoRoute(
            path: 'record',
            name: 'voiceRecording',
            builder: (context, state) => const VoiceRecordingPage(),
          ),
          // Voice Status
          GoRoute(
            path: 'status/:profileId',
            name: 'voiceStatus',
            builder: (context, state) {
              final profileId = state.pathParameters['profileId']!;
              return VoiceProfileStatusPage(profileId: profileId);
            },
          ),
        ],
      ),
      // Pending Questions
      GoRoute(
        path: AppRoutes.pendingQuestions,
        name: 'pendingQuestions',
        builder: (context, state) {
          final storyId = state.uri.queryParameters['storyId'];
          return PendingQuestionsPage(storyId: storyId);
        },
      ),
      // Settings
      GoRoute(
        path: AppRoutes.settings,
        name: 'settings',
        builder: (context, state) => const SettingsPage(),
      ),
      // Voice Selection
      GoRoute(
        path: AppRoutes.voiceSelection,
        name: 'voiceSelection',
        builder: (context, state) => const VoiceSelectionPage(),
      ),
      // Voice Store
      GoRoute(
        path: AppRoutes.voiceStore,
        name: 'voiceStore',
        builder: (context, state) => const VoiceKitStorePage(),
      ),
    ],
    errorBuilder: (context, state) => _ErrorPage(error: state.error),
  );
});

/// Error page for invalid routes.
class _ErrorPage extends StatelessWidget {
  const _ErrorPage({this.error});

  final Exception? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Error')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Page not found',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            if (error != null)
              Text(
                error.toString(),
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.storyList),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    );
  }
}
