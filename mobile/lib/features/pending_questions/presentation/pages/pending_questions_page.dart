import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme.dart';
import '../../../../core/database/enums.dart';
import '../../domain/entities/pending_question.dart';
import '../providers/pending_question_provider.dart';
import '../widgets/question_card.dart';

/// Page for displaying and managing pending questions.
class PendingQuestionsPage extends ConsumerStatefulWidget {
  const PendingQuestionsPage({
    this.storyId,
    super.key,
  });

  /// Optional story ID to filter questions.
  final String? storyId;

  @override
  ConsumerState<PendingQuestionsPage> createState() =>
      _PendingQuestionsPageState();
}

class _PendingQuestionsPageState extends ConsumerState<PendingQuestionsPage> {
  bool _showAnswered = false;

  @override
  Widget build(BuildContext context) {
    final questionsAsync = ref.watch(
      pendingQuestionsNotifierProvider(storyId: widget.storyId),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.storyId != null ? '故事問題' : '待回答問題'),
        actions: [
          // Filter toggle
          IconButton(
            icon: Icon(
              _showAnswered ? Icons.filter_list_off : Icons.filter_list,
            ),
            tooltip: _showAnswered ? '隱藏已回答' : '顯示已回答',
            onPressed: () {
              setState(() {
                _showAnswered = !_showAnswered;
              });
            },
          ),
        ],
      ),
      body: questionsAsync.when(
        data: (questions) => _buildContent(questions),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _buildErrorState(error),
      ),
    );
  }

  Widget _buildContent(List<PendingQuestion> questions) {
    // Filter based on toggle
    final filteredQuestions = _showAnswered
        ? questions
        : questions
            .where((q) => q.status == PendingQuestionStatus.pending)
            .toList();

    if (filteredQuestions.isEmpty) {
      return const PendingQuestionsEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref
            .read(pendingQuestionsNotifierProvider(storyId: widget.storyId)
                .notifier)
            .refresh();
      },
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: filteredQuestions.length,
        itemBuilder: (context, index) {
          final question = filteredQuestions[index];
          return QuestionCard(
            question: question,
            storyTitle: _getStoryTitle(question.storyId),
            onTap: () => _showQuestionDetail(question),
            onMarkAnswered: question.status == PendingQuestionStatus.answered
                ? null
                : () => _showAnswerDialog(question),
          );
        },
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              '載入失敗',
              style: AppTextStyles.headlineSmall.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                ref
                    .read(pendingQuestionsNotifierProvider(
                            storyId: widget.storyId)
                        .notifier)
                    .refresh();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('重試'),
            ),
          ],
        ),
      ),
    );
  }

  String _getStoryTitle(String storyId) {
    // TODO: Get actual story title from stories provider
    return '故事';
  }

  void _showQuestionDetail(PendingQuestion question) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _QuestionDetailSheet(
        question: question,
        storyTitle: _getStoryTitle(question.storyId),
        onMarkAnswered: () => _showAnswerDialog(question),
      ),
    );
  }

  void _showAnswerDialog(PendingQuestion question) {
    showDialog(
      context: context,
      builder: (context) => _AnswerQuestionDialog(
        question: question,
        onAnswered: () {
          ref
              .read(
                  pendingQuestionsNotifierProvider(storyId: widget.storyId)
                      .notifier)
              .refresh();
        },
      ),
    );
  }
}

/// Bottom sheet for question details.
class _QuestionDetailSheet extends StatelessWidget {
  const _QuestionDetailSheet({
    required this.question,
    required this.storyTitle,
    this.onMarkAnswered,
  });

  final PendingQuestion question;
  final String storyTitle;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAnswered = question.status == PendingQuestionStatus.answered;

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(16),
            ),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Story info
                    Row(
                      children: [
                        Icon(
                          Icons.auto_stories,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          storyTitle,
                          style: AppTextStyles.labelLarge.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _formatTimeAgo(question.askedAt),
                          style: AppTextStyles.labelLarge.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Question
                    Text(
                      '孩子的問題',
                      style: AppTextStyles.labelLarge.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        question.question,
                        style: AppTextStyles.bodyMedium.copyWith(
                          height: 1.6,
                        ),
                      ),
                    ),

                    // Answer section
                    if (isAnswered && question.answeredAt != null) ...[
                      const SizedBox(height: 24),
                      Text(
                        '已回答',
                        style: AppTextStyles.labelLarge.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '於 ${DateFormat('yyyy/MM/dd HH:mm').format(question.answeredAt!)} 標記為已回答',
                          style: AppTextStyles.bodyMedium.copyWith(
                            height: 1.6,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Action button
              if (!isAnswered && onMarkAnswered != null)
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          onMarkAnswered!();
                        },
                        icon: const Icon(Icons.check),
                        label: const Text('標記為已回答'),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Dialog for answering a question.
class _AnswerQuestionDialog extends ConsumerStatefulWidget {
  const _AnswerQuestionDialog({
    required this.question,
    required this.onAnswered,
  });

  final PendingQuestion question;
  final VoidCallback onAnswered;

  @override
  ConsumerState<_AnswerQuestionDialog> createState() =>
      _AnswerQuestionDialogState();
}

class _AnswerQuestionDialogState extends ConsumerState<_AnswerQuestionDialog> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final answerState = ref.watch(answerQuestionNotifierProvider);

    return AlertDialog(
      title: const Text('標記為已回答'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question preview
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.help_outline,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.question.question,
                    style: AppTextStyles.labelLarge,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Text(
            '將此問題標記為已回答後，問題將從待回答列表中移除。',
            style: AppTextStyles.bodyMedium.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),

          // Error message
          if (answerState.error != null) ...[
            const SizedBox(height: 8),
            Text(
              answerState.error!,
              style: AppTextStyles.labelLarge.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: answerState.isSubmitting
              ? null
              : () {
                  ref.read(answerQuestionNotifierProvider.notifier).reset();
                  Navigator.of(context).pop();
                },
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: answerState.isSubmitting
              ? null
              : () async {
                  final success = await ref
                      .read(answerQuestionNotifierProvider.notifier)
                      .submit(widget.question.id);

                  if (success && mounted) {
                    ref.read(answerQuestionNotifierProvider.notifier).reset();
                    Navigator.of(context).pop();
                    widget.onAnswered();

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('已標記為已回答')),
                    );
                  }
                },
          child: answerState.isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('確認'),
        ),
      ],
    );
  }
}
