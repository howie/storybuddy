import 'package:flutter/material.dart';

import '../../domain/entities/story_playback.dart';

/// Widget for playback control buttons.
class PlaybackControls extends StatelessWidget {
  const PlaybackControls({
    required this.playbackState,
    required this.onPlayPause,
    required this.onSeekBackward,
    required this.onSeekForward,
    required this.onStop,
    this.onSpeedChange,
    this.currentSpeed = 1.0,
    super.key,
  });

  final StoryPlayback playbackState;
  final VoidCallback onPlayPause;
  final VoidCallback onSeekBackward;
  final VoidCallback onSeekForward;
  final VoidCallback onStop;
  final void Function(double)? onSpeedChange;
  final double currentSpeed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Speed button
        if (onSpeedChange != null)
          _SpeedButton(
            speed: currentSpeed,
            onSpeedChange: onSpeedChange!,
          ),

        const SizedBox(width: 16),

        // Seek backward button
        IconButton(
          onPressed:
              playbackState.state != PlaybackState.idle ? onSeekBackward : null,
          icon: const Icon(Icons.replay_10),
          iconSize: 36,
          color: theme.colorScheme.onSurface,
        ),

        const SizedBox(width: 8),

        // Play/Pause button
        _PlayPauseButton(
          isPlaying: playbackState.isPlaying,
          isLoading: playbackState.isLoading,
          onPressed: playbackState.state != PlaybackState.idle ||
                  playbackState.isLoading
              ? onPlayPause
              : null,
        ),

        const SizedBox(width: 8),

        // Seek forward button
        IconButton(
          onPressed:
              playbackState.state != PlaybackState.idle ? onSeekForward : null,
          icon: const Icon(Icons.forward_10),
          iconSize: 36,
          color: theme.colorScheme.onSurface,
        ),

        const SizedBox(width: 16),

        // Stop button
        IconButton(
          onPressed: playbackState.state != PlaybackState.idle ? onStop : null,
          icon: const Icon(Icons.stop),
          iconSize: 32,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ],
    );
  }
}

/// Play/Pause button with loading state.
class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({
    required this.isPlaying,
    required this.isLoading,
    this.onPressed,
  });

  final bool isPlaying;
  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(36),
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: theme.colorScheme.onPrimary,
                    ),
                  )
                : Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    size: 40,
                    color: theme.colorScheme.onPrimary,
                  ),
          ),
        ),
      ),
    );
  }
}

/// Speed selection button.
class _SpeedButton extends StatelessWidget {
  const _SpeedButton({
    required this.speed,
    required this.onSpeedChange,
  });

  final double speed;
  final void Function(double) onSpeedChange;

  static const _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopupMenuButton<double>(
      initialValue: speed,
      onSelected: onSpeedChange,
      itemBuilder: (context) => _speeds
          .map((s) => PopupMenuItem(
                value: s,
                child: Text(
                  '${s}x',
                  style: TextStyle(
                    fontWeight:
                        s == speed ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),)
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          '${speed}x',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// Mini playback controls for compact display.
class MiniPlaybackControls extends StatelessWidget {
  const MiniPlaybackControls({
    required this.playbackState,
    required this.onPlayPause,
    this.onClose,
    super.key,
  });

  final StoryPlayback playbackState;
  final VoidCallback onPlayPause;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Play/Pause
          IconButton(
            onPressed: onPlayPause,
            icon: Icon(
              playbackState.isPlaying ? Icons.pause : Icons.play_arrow,
            ),
            visualDensity: VisualDensity.compact,
          ),

          // Title
          Flexible(
            child: Text(
              playbackState.storyTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Close button
          if (onClose != null)
            IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}
