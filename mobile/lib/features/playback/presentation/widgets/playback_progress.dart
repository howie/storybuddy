import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../domain/entities/story_playback.dart';

/// Widget for playback progress display and seeking.
class PlaybackProgress extends StatelessWidget {
  const PlaybackProgress({
    required this.playbackState,
    required this.onSeek,
    this.showLabels = true,
    super.key,
  });

  final StoryPlayback playbackState;
  final void Function(Duration) onSeek;
  final bool showLabels;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Progress slider
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            activeTrackColor: theme.colorScheme.primary,
            inactiveTrackColor: theme.colorScheme.surfaceContainerHighest,
            thumbColor: theme.colorScheme.primary,
            overlayColor: theme.colorScheme.primary.withOpacity(0.2),
          ),
          child: Slider(
            value: playbackState.progress,
            onChanged: playbackState.duration.inMilliseconds > 0
                ? (value) {
                    final position = Duration(
                      milliseconds:
                          (value * playbackState.duration.inMilliseconds)
                              .round(),
                    );
                    onSeek(position);
                  }
                : null,
          ),
        ),

        // Time labels
        if (showLabels)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  playbackState.formattedPosition,
                  style: AppTextStyles.labelLarge.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontFeatures: [const FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  playbackState.formattedDuration,
                  style: AppTextStyles.labelLarge.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontFeatures: [const FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Linear progress indicator with buffering display.
class BufferedProgressIndicator extends StatelessWidget {
  const BufferedProgressIndicator({
    required this.progress,
    required this.bufferedProgress,
    this.height = 4.0,
    super.key,
  });

  final double progress;
  final double bufferedProgress;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: height,
      child: Stack(
        children: [
          // Background
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(height / 2),
            ),
          ),

          // Buffered progress
          FractionallySizedBox(
            widthFactor: bufferedProgress.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.3),
                borderRadius: BorderRadius.circular(height / 2),
              ),
            ),
          ),

          // Played progress
          FractionallySizedBox(
            widthFactor: progress.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(height / 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact progress bar for mini player.
class MiniProgressBar extends StatelessWidget {
  const MiniProgressBar({
    required this.progress,
    this.height = 3.0,
    super.key,
  });

  final double progress;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: height,
      child: LinearProgressIndicator(
        value: progress.clamp(0.0, 1.0),
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
        borderRadius: BorderRadius.circular(height / 2),
      ),
    );
  }
}

/// Time remaining display.
class TimeRemaining extends StatelessWidget {
  const TimeRemaining({
    required this.remainingTime,
    super.key,
  });

  final Duration remainingTime;

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '-${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Text(
      _formatDuration(remainingTime),
      style: AppTextStyles.labelLarge.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontFeatures: [const FontFeature.tabularFigures()],
      ),
    );
  }
}
