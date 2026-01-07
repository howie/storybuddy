import 'package:flutter/material.dart';

import '../../../../app/theme.dart';

/// Empty state widget shown when no stories exist.
class StoryEmptyState extends StatelessWidget {
  const StoryEmptyState({
    this.onImportTap,
    this.onGenerateTap,
    super.key,
  });

  final VoidCallback? onImportTap;
  final VoidCallback? onGenerateTap;

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
              Icons.auto_stories_outlined,
              size: 80,
              color: theme.colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Text(
              '還沒有故事',
              style: AppTextStyles.headlineMedium.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '匯入一個故事或讓 AI 為您生成一個',
              style: AppTextStyles.bodyMedium.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: onImportTap,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('匯入故事'),
                ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed: onGenerateTap,
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('AI 生成'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
