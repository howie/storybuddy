import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../providers/settings_provider.dart';
import '../widgets/delete_data_dialog.dart';

/// Settings page for app configuration.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
      ),
      body: settingsAsync.when(
        data: (settings) => _buildContent(context, ref, settings),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('載入失敗: $error')),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) {
    final theme = Theme.of(context);

    return ListView(
      children: [
        // Appearance section
        _SectionHeader(title: '外觀'),
        _ThemeModeTile(
          currentMode: settings.themeMode,
          onChanged: (mode) {
            ref.read(settingsNotifierProvider.notifier).setThemeMode(mode);
          },
        ),
        const Divider(height: 1),

        // Playback section
        _SectionHeader(title: '播放'),
        SwitchListTile(
          title: const Text('自動播放下一篇'),
          subtitle: const Text('故事結束後自動播放下一個故事'),
          value: settings.autoPlayNext,
          onChanged: (value) {
            ref.read(settingsNotifierProvider.notifier).setAutoPlayNext(value);
          },
        ),
        const Divider(height: 1),
        SwitchListTile(
          title: const Text('Q&A 提示'),
          subtitle: const Text('故事結束後提示開始問答'),
          value: settings.qaPromptEnabled,
          onChanged: (value) {
            ref
                .read(settingsNotifierProvider.notifier)
                .setQAPromptEnabled(value);
          },
        ),
        const Divider(height: 1),

        // Data section
        _SectionHeader(title: '資料管理'),
        ListTile(
          leading: Icon(
            Icons.delete_outline,
            color: theme.colorScheme.error,
          ),
          title: Text(
            '清除本機資料',
            style: TextStyle(color: theme.colorScheme.error),
          ),
          subtitle: const Text('刪除所有快取的故事和錄音'),
          onTap: () => _showDeleteDataDialog(context, ref),
        ),
        const Divider(height: 1),

        // About section
        _SectionHeader(title: '關於'),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text('版本'),
          trailing: Text(
            '1.0.0',
            style: AppTextStyles.bodyMedium.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.description_outlined),
          title: const Text('隱私權政策'),
          trailing: const Icon(Icons.open_in_new, size: 18),
          onTap: () => _openPrivacyPolicy(context),
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.gavel_outlined),
          title: const Text('服務條款'),
          trailing: const Icon(Icons.open_in_new, size: 18),
          onTap: () => _openTermsOfService(context),
        ),
        const Divider(height: 1),

        const SizedBox(height: 32),

        // Footer
        Center(
          child: Text(
            '© 2024 StoryBuddy',
            style: AppTextStyles.labelLarge.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),

        const SizedBox(height: 32),
      ],
    );
  }

  void _showDeleteDataDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => DeleteDataDialog(
        onConfirm: () async {
          // TODO: Implement data deletion
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已清除本機資料')),
          );
        },
      ),
    );
  }

  void _openPrivacyPolicy(BuildContext context) {
    // TODO: Open privacy policy URL
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('開啟隱私權政策...')),
    );
  }

  void _openTermsOfService(BuildContext context) {
    // TODO: Open terms of service URL
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('開啟服務條款...')),
    );
  }
}

/// Section header widget.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: AppTextStyles.labelLarge.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Theme mode selection tile.
class _ThemeModeTile extends StatelessWidget {
  const _ThemeModeTile({
    required this.currentMode,
    required this.onChanged,
  });

  final ThemeMode currentMode;
  final void Function(ThemeMode) onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(_getIcon(currentMode)),
      title: const Text('主題'),
      subtitle: Text(_getModeLabel(currentMode)),
      onTap: () => _showThemePicker(context),
    );
  }

  IconData _getIcon(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return Icons.brightness_auto;
      case ThemeMode.light:
        return Icons.light_mode;
      case ThemeMode.dark:
        return Icons.dark_mode;
    }
  }

  String _getModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return '跟隨系統';
      case ThemeMode.light:
        return '淺色模式';
      case ThemeMode.dark:
        return '深色模式';
    }
  }

  void _showThemePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.brightness_auto),
              title: const Text('跟隨系統'),
              trailing: currentMode == ThemeMode.system
                  ? const Icon(Icons.check)
                  : null,
              onTap: () {
                onChanged(ThemeMode.system);
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.light_mode),
              title: const Text('淺色模式'),
              trailing: currentMode == ThemeMode.light
                  ? const Icon(Icons.check)
                  : null,
              onTap: () {
                onChanged(ThemeMode.light);
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.dark_mode),
              title: const Text('深色模式'),
              trailing: currentMode == ThemeMode.dark
                  ? const Icon(Icons.check)
                  : null,
              onTap: () {
                onChanged(ThemeMode.dark);
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}
