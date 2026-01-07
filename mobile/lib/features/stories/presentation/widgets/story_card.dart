import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../domain/entities/story.dart';

/// A card widget displaying story information.
class StoryCard extends StatelessWidget {
  const StoryCard({
    required this.story,
    this.onTap,
    this.onPlayTap,
    this.onDownloadTap,
    super.key,
  });

  final Story story;
  final VoidCallback? onTap;
  final VoidCallback? onPlayTap;
  final VoidCallback? onDownloadTap;

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
              _buildHeader(theme),
              const SizedBox(height: 8),
              _buildContent(theme),
              const SizedBox(height: 12),
              _buildFooter(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: Text(
            story.title,
            style: AppTextStyles.headlineSmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        _buildSourceBadge(theme),
      ],
    );
  }

  Widget _buildSourceBadge(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        story.sourceLabel,
        style: AppTextStyles.labelLarge.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    return Text(
      story.content,
      style: AppTextStyles.bodyMedium.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildFooter(ThemeData theme) {
    return Row(
      children: [
        _buildInfoChip(
          theme,
          Icons.text_fields,
          '${story.wordCount} 字',
        ),
        const SizedBox(width: 12),
        if (story.estimatedDurationMinutes != null)
          _buildInfoChip(
            theme,
            Icons.schedule,
            '${story.estimatedDurationMinutes} 分鐘',
          ),
        const Spacer(),
        _buildActionButtons(theme),
      ],
    );
  }

  Widget _buildInfoChip(ThemeData theme, IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTextStyles.labelLarge.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (story.hasAudio) ...[
          IconButton(
            icon: Icon(
              Icons.play_circle_outline,
              color: theme.colorScheme.primary,
            ),
            onPressed: onPlayTap,
            tooltip: '播放',
            visualDensity: VisualDensity.compact,
          ),
          if (!story.isDownloaded && story.audioUrl != null)
            IconButton(
              icon: Icon(
                Icons.download_outlined,
                color: theme.colorScheme.primary,
              ),
              onPressed: onDownloadTap,
              tooltip: '下載',
              visualDensity: VisualDensity.compact,
            ),
          if (story.isDownloaded)
            Icon(
              Icons.offline_pin,
              size: 20,
              color: theme.colorScheme.tertiary,
            ),
        ],
        if (!story.isSynced)
          Icon(
            Icons.sync_problem,
            size: 20,
            color: theme.colorScheme.error,
          ),
      ],
    );
  }
}
