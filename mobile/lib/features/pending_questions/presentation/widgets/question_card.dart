import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/database/enums.dart';
import '../../domain/entities/pending_question.dart';

/// Card widget for displaying a pending question.
class QuestionCard extends StatelessWidget {
  const QuestionCard({
    required this.question,
    required this.storyTitle,
    this.onTap,
    this.onMarkAnswered,
    super.key,
  });

  final PendingQuestion question;
  final String storyTitle;
  final VoidCallback? onTap;
  final VoidCallback? onMarkAnswered;

  String _formatTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inDays > 0) {
      return '${diff.inDays}天前';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}小時前';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}分鐘前';
    }
    return '剛剛';
  }

  bool get isAnswered => question.status == PendingQuestionStatus.answered;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with story name and time
              Row(
                children: [
                  // Story badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_stories,
                          size: 14,
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          storyTitle,
                          style: AppTextStyles.labelLarge.copyWith(
                            color: theme.colorScheme.onSecondaryContainer,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Time ago
                  Text(
                    _formatTimeAgo(question.askedAt),
                    style: AppTextStyles.labelLarge.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Question text
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.help_outline,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      question.question,
                      style: AppTextStyles.bodyMedium.copyWith(
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),

              // Answered indicator or action button
              if (isAnswered) ...[
                const SizedBox(height: 12),
                _buildAnsweredSection(context),
              ] else if (onMarkAnswered != null) ...[
                const SizedBox(height: 12),
                _buildActionSection(context),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnsweredSection(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            size: 16,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 4),
          Text(
            '已回答',
            style: AppTextStyles.labelLarge.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (question.answeredAt != null) ...[
            const SizedBox(width: 8),
            Text(
              _formatDate(question.answeredAt!),
              style: AppTextStyles.labelLarge.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionSection(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton.icon(
          onPressed: onMarkAnswered,
          icon: Icon(
            Icons.check,
            size: 18,
            color: theme.colorScheme.primary,
          ),
          label: Text(
            '標記為已回答',
            style: AppTextStyles.labelLarge.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

/// Empty state widget for no pending questions.
class PendingQuestionsEmptyState extends StatelessWidget {
  const PendingQuestionsEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 80,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              '沒有待回答的問題',
              style: AppTextStyles.headlineSmall.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '當孩子問了超出故事範圍的問題時，\n會顯示在這裡等待您回答',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Badge widget for pending question count.
class PendingQuestionBadge extends StatelessWidget {
  const PendingQuestionBadge({
    required this.count,
    super.key,
  });

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.error,
        borderRadius: BorderRadius.circular(10),
      ),
      constraints: const BoxConstraints(
        minWidth: 20,
        minHeight: 20,
      ),
      child: Center(
        child: Text(
          count > 99 ? '99+' : count.toString(),
          style: AppTextStyles.labelLarge.copyWith(
            color: theme.colorScheme.onError,
            fontWeight: FontWeight.bold,
            fontSize: 10,
          ),
        ),
      ),
    );
  }
}
