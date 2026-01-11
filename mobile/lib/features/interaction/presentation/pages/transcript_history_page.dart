import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:storybuddy/features/interaction/domain/entities/interaction_transcript.dart';
import 'package:storybuddy/features/interaction/presentation/providers/transcript_provider.dart';

/// T082 [US4] Create transcript history page.
///
/// Displays a paginated list of interaction transcripts.
class TranscriptHistoryPage extends ConsumerStatefulWidget {
  const TranscriptHistoryPage({super.key, this.storyId});

  final String? storyId;

  @override
  ConsumerState<TranscriptHistoryPage> createState() =>
      _TranscriptHistoryPageState();
}

class _TranscriptHistoryPageState extends ConsumerState<TranscriptHistoryPage> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    // Load initial data
    Future.microtask(() {
      ref.read(transcriptListProvider.notifier).loadTranscripts(
            storyId: widget.storyId,
          );
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(transcriptListProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transcriptListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('互動紀錄'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(transcriptListProvider.notifier).refresh();
            },
            tooltip: '重新整理',
          ),
        ],
      ),
      body: _buildBody(context, state),
    );
  }

  Widget _buildBody(BuildContext context, TranscriptListState state) {
    if (state.error != null && state.transcripts.isEmpty) {
      return _buildErrorState(context, state.error!);
    }

    if (state.isLoading && state.transcripts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.transcripts.isEmpty) {
      return _buildEmptyState(context);
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(transcriptListProvider.notifier).refresh(),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: state.transcripts.length + (state.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= state.transcripts.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            );
          }

          final transcript = state.transcripts[index];
          return _buildTranscriptCard(context, transcript);
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              '還沒有互動紀錄',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '開始聆聽故事並與 AI 互動，\n您的對話紀錄會顯示在這裡。',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String error) {
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
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                ref.read(transcriptListProvider.notifier).refresh();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('重試'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTranscriptCard(
    BuildContext context,
    TranscriptSummary transcript,
  ) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          context.push('/transcripts/${transcript.id}');
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      transcript.storyTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (transcript.emailSentAt != null)
                    Icon(
                      Icons.email,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('M/d HH:mm').format(transcript.createdAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.timer,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    transcript.durationText,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${transcript.turnCount} 回合',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Page for viewing a single transcript.
class TranscriptDetailPage extends ConsumerWidget {
  const TranscriptDetailPage({required this.transcriptId, super.key});

  final String transcriptId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transcriptAsync = ref.watch(transcriptProvider(transcriptId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('互動紀錄'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              _handleMenuAction(context, ref, value);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'share',
                child: ListTile(
                  leading: Icon(Icons.share),
                  title: Text('分享'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'email',
                child: ListTile(
                  leading: Icon(Icons.email),
                  title: Text('寄送電子郵件'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'export_html',
                child: ListTile(
                  leading: Icon(Icons.download),
                  title: Text('下載 HTML'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete, color: Colors.red),
                  title: Text('刪除', style: TextStyle(color: Colors.red)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: transcriptAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _buildErrorState(context, ref, error.toString()),
        data: (transcript) => _buildTranscriptView(context, ref, transcript),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref, String error) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              '無法載入紀錄',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref.invalidate(transcriptProvider(transcriptId));
              },
              child: const Text('重試'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTranscriptView(
    BuildContext context,
    WidgetRef ref,
    InteractionTranscript transcript,
  ) {
    // Import and use TranscriptViewer widget
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, transcript),
          const SizedBox(height: 16),
          _buildContent(context, transcript),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, InteractionTranscript transcript) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              transcript.storyTitle ?? '互動紀錄',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _buildInfoChip(
                  Icons.calendar_today,
                  DateFormat('yyyy/M/d HH:mm').format(transcript.createdAt),
                ),
                _buildInfoChip(Icons.timer, transcript.durationText),
                _buildInfoChip(
                  Icons.chat_bubble_outline,
                  '${transcript.turnCount} 回合',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }

  Widget _buildContent(BuildContext context, InteractionTranscript transcript) {
    final theme = Theme.of(context);

    if (transcript.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Text(
              '（此次互動沒有對話紀錄）',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    // Display plain text content formatted
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SelectableText(
          transcript.plainText,
          style: theme.textTheme.bodyMedium,
        ),
      ),
    );
  }

  void _handleMenuAction(
    BuildContext context,
    WidgetRef ref,
    String action,
  ) {
    switch (action) {
      case 'share':
        _showShareDialog(context, ref);
        break;
      case 'email':
        _showEmailDialog(context, ref);
        break;
      case 'export_html':
        _exportHtml(context, ref);
        break;
      case 'delete':
        _confirmDelete(context, ref);
        break;
    }
  }

  void _showShareDialog(BuildContext context, WidgetRef ref) {
    // Implement share functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('分享功能開發中')),
    );
  }

  void _showEmailDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => _EmailDialog(transcriptId: transcriptId),
    );
  }

  void _exportHtml(BuildContext context, WidgetRef ref) {
    // Implement export
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('下載功能開發中')),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認刪除'),
        content: const Text('確定要刪除這份互動紀錄嗎？此操作無法復原。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () async {
              Navigator.pop(context);
              final success = await ref
                  .read(transcriptRepositoryProvider)
                  .deleteTranscript(transcriptId);
              if (success && context.mounted) {
                ref
                    .read(transcriptListProvider.notifier)
                    .removeTranscript(transcriptId);
                context.pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已刪除')),
                );
              }
            },
            child: const Text('刪除'),
          ),
        ],
      ),
    );
  }
}

/// Dialog for sending transcript via email.
class _EmailDialog extends ConsumerStatefulWidget {
  const _EmailDialog({required this.transcriptId});

  final String transcriptId;

  @override
  ConsumerState<_EmailDialog> createState() => _EmailDialogState();
}

class _EmailDialogState extends ConsumerState<_EmailDialog> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sendState = ref.watch(sendEmailProvider);

    return AlertDialog(
      title: const Text('寄送互動紀錄'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: '電子郵件',
                hintText: 'parent@example.com',
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '請輸入電子郵件';
                }
                if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                  return '請輸入有效的電子郵件';
                }
                return null;
              },
            ),
            if (sendState.error != null) ...[
              const SizedBox(height: 16),
              Text(
                sendState.error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: sendState.isSending ? null : () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: sendState.isSending
              ? null
              : () async {
                  if (_formKey.currentState!.validate()) {
                    await ref.read(sendEmailProvider.notifier).sendEmail(
                          transcriptId: widget.transcriptId,
                          email: _emailController.text,
                        );
                    if (ref.read(sendEmailProvider).success && mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('已寄送')),
                      );
                    }
                  }
                },
          child: sendState.isSending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('寄送'),
        ),
      ],
    );
  }
}
