import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/theme.dart';

/// Voice input button with recording animation.
class VoiceInputButton extends StatefulWidget {
  const VoiceInputButton({
    required this.isRecording,
    required this.onStartRecording,
    required this.onStopRecording,
    required this.onCancelRecording,
    this.amplitudeStream,
    this.enabled = true,
    super.key,
  });

  final bool isRecording;
  final VoidCallback onStartRecording;
  final VoidCallback onStopRecording;
  final VoidCallback onCancelRecording;
  final Stream<double>? amplitudeStream;
  final bool enabled;

  @override
  State<VoiceInputButton> createState() => _VoiceInputButtonState();
}

class _VoiceInputButtonState extends State<VoiceInputButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  double _currentAmplitude = 0;
  StreamSubscription<double>? _amplitudeSubscription;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
  }

  @override
  void didUpdateWidget(VoiceInputButton oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isRecording && !oldWidget.isRecording) {
      _pulseController.repeat(reverse: true);
      _startListeningToAmplitude();
    } else if (!widget.isRecording && oldWidget.isRecording) {
      _pulseController.stop();
      _stopListeningToAmplitude();
    }
  }

  void _startListeningToAmplitude() {
    _amplitudeSubscription = widget.amplitudeStream?.listen((amplitude) {
      if (mounted) {
        setState(() {
          _currentAmplitude = amplitude;
        });
      }
    });
  }

  void _stopListeningToAmplitude() {
    _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;
    _currentAmplitude = 0.0;
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _amplitudeSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Recording indicator
        if (widget.isRecording) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
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
                '正在錄音...',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],

        // Main button with animation
        GestureDetector(
          onTap: widget.enabled
              ? (widget.isRecording
                  ? widget.onStopRecording
                  : widget.onStartRecording)
              : null,
          onLongPress: widget.isRecording ? widget.onCancelRecording : null,
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final pulseScale = widget.isRecording
                  ? 1.0 +
                      (_pulseController.value * 0.1) +
                      (_currentAmplitude * 0.2)
                  : 1.0;

              return Transform.scale(
                scale: pulseScale,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: widget.enabled
                        ? (widget.isRecording
                            ? theme.colorScheme.error
                            : theme.colorScheme.primary)
                        : theme.colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                    boxShadow: widget.enabled
                        ? [
                            BoxShadow(
                              color: (widget.isRecording
                                      ? theme.colorScheme.error
                                      : theme.colorScheme.primary)
                                  .withOpacity(0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    widget.isRecording ? Icons.stop : Icons.mic,
                    size: 32,
                    color: widget.enabled
                        ? (widget.isRecording
                            ? theme.colorScheme.onError
                            : theme.colorScheme.onPrimary)
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 12),

        // Hint text
        Text(
          widget.isRecording
              ? '點擊停止，長按取消'
              : (widget.enabled ? '點擊開始提問' : '已達問答上限'),
          style: AppTextStyles.labelLarge.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Compact voice input button for inline use.
class CompactVoiceInputButton extends StatelessWidget {
  const CompactVoiceInputButton({
    required this.isRecording,
    required this.onTap,
    this.enabled = true,
    super.key,
  });

  final bool isRecording;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return IconButton(
      onPressed: enabled ? onTap : null,
      icon: Icon(
        isRecording ? Icons.stop : Icons.mic,
        color: enabled
            ? (isRecording
                ? theme.colorScheme.error
                : theme.colorScheme.primary)
            : theme.colorScheme.onSurfaceVariant,
      ),
      style: IconButton.styleFrom(
        backgroundColor: enabled
            ? (isRecording
                ? theme.colorScheme.errorContainer
                : theme.colorScheme.primaryContainer)
            : theme.colorScheme.surfaceContainerHighest,
      ),
    );
  }
}
