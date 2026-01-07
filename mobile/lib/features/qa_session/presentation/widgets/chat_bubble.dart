import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/database/enums.dart';
import '../../domain/entities/qa_message.dart';

/// Chat bubble widget for displaying Q&A messages.
class ChatBubble extends StatelessWidget {
  const ChatBubble({
    required this.message,
    this.onPlayAudio,
    super.key,
  });

  final QAMessage message;
  final VoidCallback? onPlayAudio;

  @override
  Widget build(BuildContext context) {
    final isChild = message.isChildMessage;

    return Padding(
      padding: EdgeInsets.only(
        left: isChild ? 48 : 16,
        right: isChild ? 16 : 48,
        top: 8,
        bottom: 8,
      ),
      child: Row(
        mainAxisAlignment:
            isChild ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isChild) ...[
            _buildAvatar(context, isChild),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: _buildBubble(context, isChild),
          ),
          if (isChild) ...[
            const SizedBox(width: 8),
            _buildAvatar(context, isChild),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatar(BuildContext context, bool isChild) {
    final theme = Theme.of(context);

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: isChild
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.secondaryContainer,
        shape: BoxShape.circle,
      ),
      child: Icon(
        isChild ? Icons.child_care : Icons.smart_toy,
        size: 20,
        color: isChild
            ? theme.colorScheme.onPrimaryContainer
            : theme.colorScheme.onSecondaryContainer,
      ),
    );
  }

  Widget _buildBubble(BuildContext context, bool isChild) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isChild
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isChild ? 16 : 4),
          bottomRight: Radius.circular(isChild ? 4 : 16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Role label
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message.roleLabel,
                style: AppTextStyles.labelLarge.copyWith(
                  color: isChild
                      ? theme.colorScheme.onPrimaryContainer.withOpacity(0.7)
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (message.isOutOfScope) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '已記錄',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: theme.colorScheme.onTertiaryContainer,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),

          // Content
          Text(
            message.content,
            style: AppTextStyles.bodyMedium.copyWith(
              color: isChild
                  ? theme.colorScheme.onPrimaryContainer
                  : theme.colorScheme.onSurface,
            ),
          ),

          // Audio button for AI messages
          if (!isChild && message.hasAudio) ...[
            const SizedBox(height: 8),
            _buildAudioButton(context),
          ],
        ],
      ),
    );
  }

  Widget _buildAudioButton(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onPlayAudio,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(
            color: theme.colorScheme.outline.withOpacity(0.5),
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.volume_up,
              size: 16,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 4),
            Text(
              '播放',
              style: AppTextStyles.labelLarge.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Typing indicator bubble shown while AI is processing.
class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 48, top: 8, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.smart_toy,
              size: 20,
              color: theme.colorScheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (index) {
                    final delay = index * 0.2;
                    final value = ((_controller.value + delay) % 1.0);
                    final opacity = 0.3 + (0.7 * (1 - (value - 0.5).abs() * 2));

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurfaceVariant
                            .withOpacity(opacity),
                        shape: BoxShape.circle,
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
