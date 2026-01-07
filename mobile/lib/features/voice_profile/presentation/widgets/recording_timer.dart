import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../domain/entities/voice_profile.dart';

/// Widget that displays recording elapsed time with visual feedback.
class RecordingTimer extends StatefulWidget {
  const RecordingTimer({
    required this.isRecording,
    this.onTick,
    this.minDuration = VoiceProfile.minDurationSeconds,
    this.maxDuration = VoiceProfile.maxDurationSeconds,
    super.key,
  });

  final bool isRecording;
  final void Function(int seconds)? onTick;
  final int minDuration;
  final int maxDuration;

  @override
  State<RecordingTimer> createState() => _RecordingTimerState();
}

class _RecordingTimerState extends State<RecordingTimer> {
  Timer? _timer;
  int _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    if (widget.isRecording) {
      _startTimer();
    }
  }

  @override
  void didUpdateWidget(RecordingTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecording && !oldWidget.isRecording) {
      _startTimer();
    } else if (!widget.isRecording && oldWidget.isRecording) {
      _stopTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _elapsedSeconds = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _elapsedSeconds++;
        widget.onTick?.call(_elapsedSeconds);
      });
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = _elapsedSeconds / widget.maxDuration;
    final hasReachedMin = _elapsedSeconds >= widget.minDuration;
    final hasReachedMax = _elapsedSeconds >= widget.maxDuration;

    Color progressColor;
    if (hasReachedMax) {
      progressColor = theme.colorScheme.error;
    } else if (hasReachedMin) {
      progressColor = theme.colorScheme.tertiary;
    } else {
      progressColor = theme.colorScheme.primary;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Timer display
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.isRecording)
              Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error,
                  shape: BoxShape.circle,
                ),
              ),
            Text(
              _formatTime(_elapsedSeconds),
              style: AppTextStyles.headlineLarge.copyWith(
                fontFeatures: [const FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 8),

        // Duration labels
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '最少 ${widget.minDuration} 秒',
              style: AppTextStyles.labelLarge.copyWith(
                color: hasReachedMin
                    ? theme.colorScheme.tertiary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              '最多 ${widget.maxDuration} 秒',
              style: AppTextStyles.labelLarge.copyWith(
                color: hasReachedMax
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),

        // Status message
        if (!hasReachedMin && widget.isRecording) ...[
          const SizedBox(height: 8),
          Text(
            '還需 ${widget.minDuration - _elapsedSeconds} 秒',
            style: AppTextStyles.bodyMedium.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ],
        if (hasReachedMin && !hasReachedMax && widget.isRecording) ...[
          const SizedBox(height: 8),
          Text(
            '已達最低要求，可以停止錄音',
            style: AppTextStyles.bodyMedium.copyWith(
              color: theme.colorScheme.tertiary,
            ),
          ),
        ],
        if (hasReachedMax) ...[
          const SizedBox(height: 8),
          Text(
            '已達最長時間',
            style: AppTextStyles.bodyMedium.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }
}

/// Compact timer display for the recording button area.
class CompactRecordingTimer extends StatelessWidget {
  const CompactRecordingTimer({
    required this.elapsedSeconds,
    this.minDuration = VoiceProfile.minDurationSeconds,
    super.key,
  });

  final int elapsedSeconds;
  final int minDuration;

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasReachedMin = elapsedSeconds >= minDuration;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: theme.colorScheme.error,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _formatTime(elapsedSeconds),
          style: AppTextStyles.bodyMedium.copyWith(
            fontFeatures: [const FontFeature.tabularFigures()],
            color: hasReachedMin
                ? theme.colorScheme.tertiary
                : theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
