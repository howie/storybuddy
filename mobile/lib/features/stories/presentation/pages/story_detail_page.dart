import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme.dart';
import '../../../../core/database/enums.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../../playback/presentation/providers/playback_provider.dart';
import '../../../voice_profile/domain/entities/voice_profile.dart';
import '../../../voice_profile/presentation/providers/voice_profile_provider.dart';
import '../../domain/entities/story.dart';
import '../providers/story_provider.dart';

/// Page displaying story details.
class StoryDetailPage extends ConsumerWidget {
  const StoryDetailPage({
    required this.storyId,
    super.key,
  });

  final String storyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storyAsync = ref.watch(storyDetailNotifierProvider(storyId));
    final voiceProfilesAsync = ref.watch(voiceProfileListNotifierProvider);
    final playbackState = ref.watch(playbackNotifierProvider);

    // Get the latest ready voice profile
    final readyVoiceProfile = _getReadyVoiceProfile(voiceProfilesAsync);

    return Scaffold(
      body: storyAsync.when(
        loading: () => const LoadingIndicator(),
        error: (error, stack) => AppErrorWidget(
          message: '無法載入故事',
          onRetry: () {
            ref.invalidate(storyDetailNotifierProvider(storyId));
          },
        ),
        data: (story) {
          if (story == null) {
            return const AppErrorWidget(message: '找不到故事');
          }

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 120,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    story.title,
                    style: AppTextStyles.headlineSmall.copyWith(
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context).colorScheme.primaryContainer,
                        ],
                      ),
                    ),
                  ),
                ),
                actions: [
                  PopupMenuButton<String>(
                    onSelected: (value) => _handleMenuAction(
                      context,
                      ref,
                      value,
                    ),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit),
                          title: Text('編輯'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(Icons.delete),
                          title: Text('刪除'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMetaInfo(context, story),
                      const SizedBox(height: 24),
                      _buildContent(context, story.content),
                      if (story.keywords != null &&
                          story.keywords!.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _buildKeywords(context, story.keywords!),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: storyAsync.when(
        loading: () => null,
        error: (_, __) => null,
        data: (story) {
          if (story == null) return null;

          return _buildFAB(
            context,
            ref,
            story,
            readyVoiceProfile,
            playbackState.isLoading,
          );
        },
      ),
    );
  }

  /// Gets the latest ready voice profile from the async value.
  VoiceProfile? _getReadyVoiceProfile(
    AsyncValue<List<VoiceProfile>> voiceProfilesAsync,
  ) {
    final profiles = voiceProfilesAsync.valueOrNull;
    if (profiles == null || profiles.isEmpty) return null;

    final readyProfiles =
        profiles.where((p) => p.status == VoiceProfileStatus.ready).toList();
    if (readyProfiles.isEmpty) return null;

    // Return the most recently created ready profile
    readyProfiles.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return readyProfiles.first;
  }

  /// Builds the appropriate FAB based on story and voice profile state.
  Widget? _buildFAB(
    BuildContext context,
    WidgetRef ref,
    Story story,
    VoiceProfile? readyVoiceProfile,
    bool isGenerating,
  ) {
    // Show loading indicator when generating audio
    if (isGenerating) {
      return const FloatingActionButton.extended(
        onPressed: null,
        icon: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white,
          ),
        ),
        label: Text('生成中...'),
      );
    }

    // If story has audio, show play options
    if (story.hasAudio) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Interactive playback button
          FloatingActionButton.small(
            heroTag: 'interactive_play',
            onPressed: () => _navigateToInteractivePlayback(context),
            tooltip: '互動模式',
            child: const Icon(Icons.mic),
          ),
          const SizedBox(height: 12),
          // Standard playback button
          FloatingActionButton.extended(
            heroTag: 'standard_play',
            onPressed: () => _navigateToPlayback(context),
            icon: const Icon(Icons.play_arrow),
            label: const Text('播放故事'),
          ),
        ],
      );
    }

    // If has ready voice profile, show generate button
    if (readyVoiceProfile != null) {
      return FloatingActionButton.extended(
        onPressed: () => _generateAudio(context, ref, readyVoiceProfile.id),
        icon: const Icon(Icons.record_voice_over),
        label: const Text('生成語音'),
      );
    }

    // No voice profile, show record button
    return FloatingActionButton.extended(
      onPressed: () => _navigateToVoiceRecording(context),
      icon: const Icon(Icons.mic),
      label: const Text('錄製聲音'),
    );
  }

  Future<void> _generateAudio(
    BuildContext context,
    WidgetRef ref,
    String voiceProfileId,
  ) async {
    try {
      await ref.read(playbackNotifierProvider.notifier).generateAudio(
            storyId: storyId,
            voiceProfileId: voiceProfileId,
          );

      // Refresh story to get updated audio URL
      ref.invalidate(storyDetailNotifierProvider(storyId));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('語音生成完成！'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on Exception catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('語音生成失敗：$e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _navigateToVoiceRecording(BuildContext context) {
    context.push('/voice-profile');
  }

  Widget _buildMetaInfo(BuildContext context, Story story) {
    final theme = Theme.of(context);

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        _buildChip(
          theme,
          Icons.label_outline,
          story.sourceLabel,
        ),
        _buildChip(
          theme,
          Icons.text_fields,
          '${story.wordCount} 字',
        ),
        if (story.estimatedDurationMinutes != null)
          _buildChip(
            theme,
            Icons.schedule,
            '${story.estimatedDurationMinutes} 分鐘',
          ),
        if (story.isDownloaded)
          _buildChip(
            theme,
            Icons.offline_pin,
            '已下載',
            color: theme.colorScheme.tertiary,
          ),
        if (!story.isSynced)
          _buildChip(
            theme,
            Icons.sync_problem,
            '待同步',
            color: theme.colorScheme.error,
          ),
      ],
    );
  }

  Widget _buildChip(
    ThemeData theme,
    IconData icon,
    String label, {
    Color? color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: (color ?? theme.colorScheme.primary).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: color ?? theme.colorScheme.primary,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.labelLarge.copyWith(
              color: color ?? theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '故事內容',
          style: AppTextStyles.headlineSmall,
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: SelectableText(
            content,
            style: AppTextStyles.bodyMedium.copyWith(
              height: 1.8,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildKeywords(BuildContext context, List<String> keywords) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '關鍵字',
          style: AppTextStyles.headlineSmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: keywords.map((keyword) {
            return Chip(
              label: Text(keyword),
              backgroundColor: theme.colorScheme.secondaryContainer,
            );
          }).toList(),
        ),
      ],
    );
  }

  void _handleMenuAction(
    BuildContext context,
    WidgetRef ref,
    String action,
  ) {
    switch (action) {
      case 'edit':
        context.push('/stories/$storyId/edit');
      case 'delete':
        _showDeleteConfirmation(context, ref);
    }
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('刪除故事'),
        content: const Text('確定要刪除這個故事嗎？此操作無法復原。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref
                  .read(storyListNotifierProvider.notifier)
                  .deleteStory(storyId);
              if (context.mounted) {
                context.pop();
              }
            },
            child: const Text('刪除'),
          ),
        ],
      ),
    );
  }

  void _navigateToPlayback(BuildContext context) {
    context.push('/stories/$storyId/play');
  }

  void _navigateToInteractivePlayback(BuildContext context) {
    context.push('/stories/$storyId/play/interactive');
  }
}
