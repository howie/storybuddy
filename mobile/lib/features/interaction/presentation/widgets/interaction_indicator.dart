import 'package:flutter/material.dart';

import 'package:storybuddy/features/interaction/presentation/providers/interaction_provider.dart';

/// Visual indicator for interaction session status.
///
/// T043 [US1] Create interaction indicator widget.
/// Shows current state: listening, child speaking, AI responding, etc.
class InteractionIndicator extends StatelessWidget {
  const InteractionIndicator({
    required this.state, super.key,
    this.showLabel = true,
  });

  /// Current interaction state.
  final InteractionState state;

  /// Whether to show text label below the indicator.
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final (icon, color, label, shouldPulse) = _getIndicatorConfig(colorScheme);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _AnimatedIndicator(
          icon: icon,
          color: color,
          shouldPulse: shouldPulse,
        ),
        if (showLabel) ...[
          const SizedBox(height: 8),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: color,
            ),
          ),
        ],
      ],
    );
  }

  (IconData, Color, String, bool) _getIndicatorConfig(ColorScheme colorScheme) {
    // Priority order for status display
    if (state.status == SessionStatus.error) {
      return (
        Icons.error_outline,
        colorScheme.error,
        state.errorMessage ?? '發生錯誤',
        false,
      );
    }

    if (state.status == SessionStatus.calibrating) {
      return (
        Icons.tune,
        colorScheme.tertiary,
        '正在校準環境...',
        true,
      );
    }

    if (state.isAIResponding) {
      return (
        Icons.smart_toy,
        colorScheme.secondary,
        '正在回應...',
        true,
      );
    }

    if (state.isWaitingForAIResponse) {
      return (
        Icons.hourglass_empty,
        colorScheme.secondary,
        '思考中...',
        true,
      );
    }

    if (state.isChildSpeaking) {
      return (
        Icons.record_voice_over,
        colorScheme.primary,
        '正在聆聽...',
        true,
      );
    }

    if (state.isListening && state.mode == SessionMode.interactive) {
      return (
        Icons.mic,
        colorScheme.primary,
        '互動模式',
        false,
      );
    }

    if (state.status == SessionStatus.paused) {
      return (
        Icons.pause_circle_outline,
        colorScheme.outline,
        '已暫停',
        false,
      );
    }

    // Default: passive mode or idle
    return (
      Icons.volume_up,
      colorScheme.outline,
      '單向播放',
      false,
    );
  }
}

/// Animated indicator with optional pulsing effect.
class _AnimatedIndicator extends StatefulWidget {
  const _AnimatedIndicator({
    required this.icon,
    required this.color,
    required this.shouldPulse,
  });

  final IconData icon;
  final Color color;
  final bool shouldPulse;

  @override
  State<_AnimatedIndicator> createState() => _AnimatedIndicatorState();
}

class _AnimatedIndicatorState extends State<_AnimatedIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ),);

    _opacityAnimation = Tween<double>(
      begin: 1,
      end: 0.5,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ),);

    if (widget.shouldPulse) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_AnimatedIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shouldPulse != oldWidget.shouldPulse) {
      if (widget.shouldPulse) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
        _controller.reset();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: widget.shouldPulse ? _scaleAnimation.value : 1.0,
          child: Opacity(
            opacity: widget.shouldPulse ? _opacityAnimation.value : 1.0,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: widget.color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                widget.icon,
                size: 32,
                color: widget.color,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Compact version of the interaction indicator for inline display.
class CompactInteractionIndicator extends StatelessWidget {
  const CompactInteractionIndicator({
    required this.state, super.key,
  });

  final InteractionState state;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (icon, color) = _getCompactConfig(colorScheme);

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: 16,
        color: color,
      ),
    );
  }

  (IconData, Color) _getCompactConfig(ColorScheme colorScheme) {
    if (state.isAIResponding || state.isWaitingForAIResponse) {
      return (Icons.smart_toy, colorScheme.secondary);
    }
    if (state.isChildSpeaking) {
      return (Icons.record_voice_over, colorScheme.primary);
    }
    if (state.isListening) {
      return (Icons.mic, colorScheme.primary);
    }
    return (Icons.volume_up, colorScheme.outline);
  }
}
