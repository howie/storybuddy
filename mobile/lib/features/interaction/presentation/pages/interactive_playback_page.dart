import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:storybuddy/app/theme.dart';
import 'package:storybuddy/features/interaction/presentation/providers/interaction_provider.dart';
import 'package:storybuddy/features/interaction/presentation/widgets/connection_status_widget.dart';
import 'package:storybuddy/features/interaction/presentation/widgets/interaction_indicator.dart';
import 'package:storybuddy/features/playback/domain/entities/story_playback.dart';
import 'package:storybuddy/features/playback/presentation/providers/playback_provider.dart';
import 'package:storybuddy/features/playback/presentation/widgets/playback_controls.dart';
import 'package:storybuddy/features/playback/presentation/widgets/playback_progress.dart';
import 'package:storybuddy/features/stories/presentation/providers/story_provider.dart';
import 'package:storybuddy/shared/widgets/error_widget.dart';
import 'package:storybuddy/shared/widgets/loading_indicator.dart';
import 'package:storybuddy/shared/widgets/mode_toggle.dart';

/// Page for interactive story playback with real-time voice interaction.
///
/// T044 [US1] Create interactive playback page.
/// Combines story playback with voice interaction capabilities.
class InteractivePlaybackPage extends ConsumerStatefulWidget {
  const InteractivePlaybackPage({
    required this.storyId,
    super.key,
  });

  final String storyId;

  @override
  ConsumerState<InteractivePlaybackPage> createState() =>
      _InteractivePlaybackPageState();
}

class _InteractivePlaybackPageState
    extends ConsumerState<InteractivePlaybackPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Start playback
      ref.read(playbackNotifierProvider.notifier).play(widget.storyId);
    });
  }

  @override
  void dispose() {
    // End interaction session when leaving
    ref.read(interactionProvider.notifier).endSession();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final storyAsync = ref.watch(storyDetailNotifierProvider(widget.storyId));
    final playbackState = ref.watch(playbackNotifierProvider);
    final interactionState = ref.watch(interactionProvider);

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

          return Stack(
            children: [
              CustomScrollView(
                slivers: [
                  // App bar with mode toggle
                  SliverAppBar(
                    expandedHeight: 160,
                    pinned: true,
                    actions: [
                      // Mode toggle in app bar
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ModeToggle(
                          isInteractive:
                              interactionState.mode == SessionMode.interactive,
                          onChanged: _onModeChanged,
                          enabled:
                              interactionState.status != SessionStatus.error,
                        ),
                      ),
                    ],
                    flexibleSpace: FlexibleSpaceBar(
                      title: Text(
                        story.title,
                        style: AppTextStyles.headlineSmall.copyWith(
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                      background: Container(
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
                            size: 60,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimary
                                .withOpacity(0.3),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Main content
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          // Interactive indicator
                          if (interactionState.mode ==
                              SessionMode.interactive) ...[
                            InteractionIndicator(state: interactionState),
                            const SizedBox(height: 16),
                          ],

                          // Transcription display
                          if (interactionState.currentTranscript.isNotEmpty ||
                              interactionState
                                  .currentAIResponseText.isNotEmpty)
                            _buildTranscriptionCard(interactionState),

                          // Story preview
                          Expanded(
                            child: _buildStoryPreview(story.content),
                          ),

                          const SizedBox(height: 16),

                          // T097 [P] Connection status indicator
                          if (interactionState.mode == SessionMode.interactive)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: ConnectionStatusWidget(
                                isConnected: interactionState.isConnected,
                                isReconnecting: interactionState.isReconnecting,
                                reconnectAttempts: interactionState.reconnectAttempts,
                                maxReconnectAttempts: interactionState.maxReconnectAttempts,
                                errorMessage: interactionState.errorMessage,
                                onRetry: () {
                                  ref.read(interactionProvider.notifier).reconnect();
                                },
                                onDismiss: () {
                                  ref.read(interactionProvider.notifier).dismissError();
                                },
                              ),
                            ),

                          // Playback error message (non-connection errors)
                          if (playbackState.hasError)
                            _buildErrorMessage(
                              playbackState.errorMessage ?? '播放發生錯誤',
                              true,
                            ),

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
                            onPlayPause: _handlePlayPause,
                            onSeekBackward: () => _handleSeek(-10),
                            onSeekForward: () => _handleSeek(10),
                            onStop: _handleStop,
                            onSpeedChange: (speed) {
                              ref
                                  .read(playbackNotifierProvider.notifier)
                                  .setSpeed(speed);
                            },
                            currentSpeed: playbackState.speed,
                          ),

                          const SizedBox(height: 16),

                          // Status indicators
                          _buildStatusIndicators(
                              playbackState, interactionState),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // T097 [P] Loading overlay during session initialization
              if (interactionState.isLoading)
                const SessionLoadingOverlay(
                  message: '正在連線...',
                ),

              // Calibration overlay
              if (interactionState.status == SessionStatus.calibrating &&
                  !interactionState.isLoading)
                _buildCalibrationOverlay(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTranscriptionCard(InteractionState state) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: state.isChildSpeaking
              ? Theme.of(context).colorScheme.primary
              : state.isAIResponding
                  ? Theme.of(context).colorScheme.secondary
                  : Theme.of(context).colorScheme.outline.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (state.currentTranscript.isNotEmpty) ...[
            Row(
              children: [
                Icon(
                  Icons.child_care,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '小朋友說：',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              state.currentTranscript,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          if (state.currentAIResponseText.isNotEmpty) ...[
            if (state.currentTranscript.isNotEmpty) const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.smart_toy,
                  size: 16,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                const SizedBox(width: 8),
                Text(
                  'AI 回應：',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              state.currentAIResponseText,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ],
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

  Widget _buildErrorMessage(String message, bool isRecoverable) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
          if (isRecoverable)
            TextButton(
              onPressed: () {
                ref.read(interactionProvider.notifier).retry();
              },
              child: const Text('重試'),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicators(
      StoryPlayback playbackState, InteractionState interactionState) {
    final indicators = <Widget>[];

    if (playbackState.isOffline) {
      indicators.add(_buildIndicatorChip(
        Icons.offline_pin,
        '離線播放',
        Theme.of(context).colorScheme.tertiary,
      ));
    }

    if (interactionState.mode == SessionMode.interactive &&
        interactionState.isListening) {
      indicators.add(_buildIndicatorChip(
        Icons.mic,
        '聆聽中',
        Theme.of(context).colorScheme.primary,
      ));
    }

    if (indicators.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: indicators
          .expand((w) => [w, const SizedBox(width: 16)])
          .toList()
        ..removeLast(),
    );
  }

  Widget _buildIndicatorChip(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTextStyles.labelLarge.copyWith(color: color),
        ),
      ],
    );
  }

  /// T094 [US5] Build calibration overlay with progress indicator.
  Widget _buildCalibrationOverlay() {
    final interactionState = ref.watch(interactionProvider);
    final progress = interactionState.calibrationProgress;
    final noiseFloorDb = interactionState.noiseFloorDb;
    final isQuiet = interactionState.isQuietEnvironment;

    return Container(
      color: Colors.black54,
      child: Center(
        child: Card(
          margin: const EdgeInsets.all(32),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated mic icon
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 1.0, end: 1.15),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeInOut,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: progress < 1.0 ? value : 1.0,
                      child: Icon(
                        progress >= 1.0
                            ? Icons.check_circle
                            : Icons.hearing,
                        size: 48,
                        color: progress >= 1.0
                            ? Colors.green
                            : Theme.of(context).colorScheme.primary,
                      ),
                    );
                  },
                  onEnd: () {
                    // This will restart the animation
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  progress >= 1.0 ? '校準完成' : '正在校準環境音量...',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  progress >= 1.0
                      ? (noiseFloorDb != null
                          ? '噪音等級：${noiseFloorDb.toStringAsFixed(1)} dB'
                          : '準備開始')
                      : '請保持安靜幾秒鐘',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                if (progress >= 1.0 && isQuiet != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isQuiet ? Icons.check_circle : Icons.warning,
                        size: 16,
                        color: isQuiet ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isQuiet ? '環境安靜，適合互動' : '環境較吵，可能影響偵測',
                        style: TextStyle(
                          fontSize: 12,
                          color: isQuiet ? Colors.green : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                // Progress bar
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                const SizedBox(height: 8),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    ref
                        .read(interactionProvider.notifier)
                        .completeCalibration();
                  },
                  child: const Text('跳過校準'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onModeChanged(bool isInteractive) async {
    final notifier = ref.read(interactionProvider.notifier);

    if (isInteractive) {
      // Switch to interactive mode
      await notifier.startSession(
        storyId: widget.storyId,
        token: '', // TODO: Get from auth provider
      );
    } else {
      // Switch to passive mode
      await notifier.switchMode(SessionMode.passive);
    }
  }

  void _handlePlayPause() {
    final playbackNotifier = ref.read(playbackNotifierProvider.notifier);
    final interactionState = ref.read(interactionProvider);

    // If in interactive mode and AI is responding, don't allow play
    if (interactionState.isAIResponding) {
      return;
    }

    playbackNotifier.toggle();

    // Sync position with server
    if (interactionState.mode == SessionMode.interactive) {
      final position = ref.read(playbackNotifierProvider).position;
      ref
          .read(interactionProvider.notifier)
          .updatePosition(position.inMilliseconds);
    }
  }

  void _handleSeek(int seconds) {
    final playbackState = ref.read(playbackNotifierProvider);
    final newPosition = playbackState.position + Duration(seconds: seconds);

    ref.read(playbackNotifierProvider.notifier).seekTo(
          newPosition.isNegative
              ? Duration.zero
              : (newPosition > playbackState.duration
                  ? playbackState.duration
                  : newPosition),
        );
  }

  void _handleStop() {
    ref.read(playbackNotifierProvider.notifier).stop();
    ref.read(interactionProvider.notifier).endSession();
    context.pop();
  }
}
