import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'app/theme.dart';
import 'core/audio/audio_handler.dart';
import 'core/init/app_initializer.dart';
import 'features/settings/presentation/providers/settings_provider.dart';

Future<void> main() async {
  // Initialize app
  await AppInitializer.initialize();

  // Initialize audio service for background playback
  await initAudioService();

  runApp(
    const ProviderScope(
      child: StoryBuddyApp(),
    ),
  );
}

/// The root widget of the StoryBuddy app.
class StoryBuddyApp extends ConsumerWidget {
  const StoryBuddyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(currentThemeModeProvider);

    return MaterialApp.router(
      title: 'StoryBuddy',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
