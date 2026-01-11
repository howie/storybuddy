import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../../stories/presentation/providers/story_provider.dart';
import '../providers/playback_provider.dart';
import '../widgets/playback_controls.dart';
import '../widgets/playback_progress.dart';

/// Page for playing story audio with controls.
class PlaybackPage extends ConsumerStatefulWidget {
  const PlaybackPage({
    required this.storyId,
    super.key,
  });

  final String storyId;

  @override
  ConsumerState<PlaybackPage> createState() => _PlaybackPageState();
}

class _PlaybackPageState extends ConsumerState<PlaybackPage> {
  bool _hasShownQAPrompt = false;

  @override
  void initState() {
    super.initState();
    // Start playing when page opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(playbackNotifierProvider.notifier).play(widget.storyId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final storyAsync = ref.watch(storyDetailNotifierProvider(widget.storyId));
    final playbackState = ref.watch(playbackNotifierProvider);

    // Show Q&A prompt when playback completes
    if (playbackState.isCompleted && !_hasShownQAPrompt) {
      _hasShownQAPrompt = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showQAPrompt();
      });
    }

    return Scaffold(
      body: storyAsync.when(
        loading: () => const LoadingIndicator(),
        error: (error, stack) => AppErrorWidget(
          message: '無法載入故事',
          onRetry: () {
            ref.invalidate(storyDetailNotifierProvider(widget.storyId));
          },
        ),
        data: (story) {
          if (story == null) {
            return const AppErrorWidget(message: '找不到故事');
          }

          return CustomScrollView(
            slivers: [
              // App bar
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    story.title,
                    style: AppTextStyles.headlineSmall.copyWith(
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                  background: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context).colorScheme.secondary,
                        ],
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.auto_stories,
                        size: 80,
                        color: Theme.of(context)
                            .colorScheme
                            .onPrimary
                            .withOpacity(0.3),
                      ),
                    ),
                  ),
                ),
              ),

              // Content
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      // Story preview
                      Expanded(
                        child: _buildStoryPreview(story.content),
                      ),

                      const SizedBox(height: 24),

                      // Error message
                      if (playbackState.hasError) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onErrorContainer,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  playbackState.errorMessage ?? '播放失敗',
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onErrorContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Progress bar
                      PlaybackProgress(
                        playbackState: playbackState,
                        onSeek: (position) {
                          ref
                              .read(playbackNotifierProvider.notifier)
                              .seekTo(position);
                        },
                      ),

                      const SizedBox(height: 24),

                      // Playback controls
                      PlaybackControls(
                        playbackState: playbackState,
                        onPlayPause: () {
                          ref.read(playbackNotifierProvider.notifier).toggle();
                        },
                        onSeekBackward: () {
                          final newPosition = playbackState.position -
                              const Duration(seconds: 10);
                          ref.read(playbackNotifierProvider.notifier).seekTo(
                                newPosition.isNegative
                                    ? Duration.zero
                                    : newPosition,
                              );
                        },
                        onSeekForward: () {
                          final newPosition = playbackState.position +
                              const Duration(seconds: 10);
                          ref.read(playbackNotifierProvider.notifier).seekTo(
                                newPosition > playbackState.duration
                                    ? playbackState.duration
                                    : newPosition,
                              );
                        },
                        onStop: () {
                          ref.read(playbackNotifierProvider.notifier).stop();
                        },
                        onSpeedChange: (speed) {
                          ref
                              .read(playbackNotifierProvider.notifier)
                              .setSpeed(speed);
                        },
                        currentSpeed: playbackState.speed,
                      ),

                      const SizedBox(height: 16),

                      // Offline indicator
                      if (playbackState.isOffline)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.offline_pin,
                              size: 16,
                              color: Theme.of(context).colorScheme.tertiary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '離線播放',
                              style: AppTextStyles.labelLarge.copyWith(
                                color: Theme.of(context).colorScheme.tertiary,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStoryPreview(String content) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: SingleChildScrollView(
        child: Text(
          content,
          style: AppTextStyles.bodyMedium.copyWith(
            height: 1.8,
          ),
        ),
      ),
    );
  }

  void _showQAPrompt() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.chat_bubble_outline),
            SizedBox(width: 8),
            Text('故事結束了！'),
          ],
        ),
        content: const Text('想問問題嗎？開始故事問答吧！'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              this.context.pop();
            },
            child: const Text('不用了'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              context.push('/qa-session/${widget.storyId}');
            },
            icon: const Icon(Icons.mic),
            label: const Text('開始問答'),
          ),
        ],
      ),
    );
  }
}
