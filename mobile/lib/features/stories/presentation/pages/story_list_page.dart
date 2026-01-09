import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/connectivity_service.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../providers/story_provider.dart';
import '../widgets/story_card.dart';
import '../widgets/story_empty_state.dart';

/// Page displaying the list of stories.
class StoryListPage extends ConsumerWidget {
  const StoryListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storiesAsync = ref.watch(storyListNotifierProvider);
    final isOnline = ref.watch(connectivityStatusProvider).valueOrNull ?? true;

    // Determine if story list is empty (for conditional FAB display)
    final hasStories = storiesAsync.valueOrNull?.isNotEmpty ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的故事'),
        actions: [
          if (!isOnline)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.cloud_off, size: 20),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(storyListNotifierProvider.notifier).refresh();
        },
        child: storiesAsync.when(
          loading: () => const LoadingIndicator(),
          error: (error, stack) => AppErrorWidget(
            message: '無法載入故事列表',
            onRetry: () {
              ref.invalidate(storyListNotifierProvider);
            },
          ),
          data: (stories) {
            if (stories.isEmpty) {
              return StoryEmptyState(
                onImportTap: () => _navigateToImport(context),
                onGenerateTap: () => _navigateToGenerate(context),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: stories.length,
              itemBuilder: (context, index) {
                final story = stories[index];
                return StoryCard(
                  story: story,
                  onTap: () => _navigateToDetail(context, story.id),
                  onPlayTap: story.hasAudio
                      ? () => _navigateToPlayback(context, story.id)
                      : null,
                  onDownloadTap: () => _downloadAudio(ref, story.id),
                );
              },
            );
          },
        ),
      ),
      // Hide FAB when empty state is shown (empty state has its own action buttons)
      floatingActionButton: hasStories
          ? FloatingActionButton.extended(
              onPressed: () => _showAddOptions(context),
              icon: const Icon(Icons.add),
              label: const Text('新增故事'),
            )
          : null,
    );
  }

  void _navigateToDetail(BuildContext context, String storyId) {
    context.push('/stories/$storyId');
  }

  void _navigateToPlayback(BuildContext context, String storyId) {
    context.push('/playback/$storyId');
  }

  void _navigateToImport(BuildContext context) {
    context.push('/stories/import');
  }

  void _navigateToGenerate(BuildContext context) {
    context.push('/stories/generate');
  }

  Future<void> _downloadAudio(WidgetRef ref, String storyId) async {
    try {
      await ref.read(storyListNotifierProvider.notifier).downloadAudio(storyId);
    } catch (e) {
      // Show error snackbar
    }
  }

  void _showAddOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.upload_file),
                title: const Text('匯入故事'),
                subtitle: const Text('從文字匯入故事內容'),
                onTap: () {
                  Navigator.pop(context);
                  _navigateToImport(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.auto_awesome),
                title: const Text('AI 生成'),
                subtitle: const Text('用關鍵字讓 AI 創作故事'),
                onTap: () {
                  Navigator.pop(context);
                  _navigateToGenerate(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
