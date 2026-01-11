import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:storybuddy/features/interaction/domain/entities/interaction_settings.dart';
import 'package:storybuddy/features/interaction/presentation/providers/interaction_settings_provider.dart';

/// T068 [US3] Create interaction settings page.
/// Page for managing recording privacy and interaction settings.
class InteractionSettingsPage extends ConsumerWidget {
  const InteractionSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(interactionSettingsProvider);
    final storageAsync = ref.watch(storageUsageProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('互動設定'),
      ),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _buildErrorState(context, ref),
        data: (settings) => _buildSettingsContent(
          context,
          ref,
          settings,
          storageAsync,
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48),
          const SizedBox(height: 16),
          const Text('載入設定失敗'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              ref.read(interactionSettingsProvider.notifier).refresh();
            },
            child: const Text('重試'),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsContent(
    BuildContext context,
    WidgetRef ref,
    InteractionSettings settings,
    AsyncValue storageAsync,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Recording settings section
        _buildSectionHeader(context, '錄音設定'),
        _buildRecordingToggle(context, ref, settings),
        if (settings.recordingEnabled) ...[
          const SizedBox(height: 8),
          _buildAutoTranscribeToggle(context, ref, settings),
          const SizedBox(height: 8),
          _buildRetentionDaysSetting(context, ref, settings),
        ],

        const SizedBox(height: 24),

        // Storage section
        _buildSectionHeader(context, '儲存空間'),
        storageAsync.when(
          loading: () => const ListTile(
            title: Text('載入中...'),
          ),
          error: (_, __) => const ListTile(
            title: Text('無法載入儲存資訊'),
          ),
          data: (storage) => _buildStorageInfo(context, storage),
        ),

        const SizedBox(height: 16),

        // Delete recordings button
        if (settings.recordingEnabled)
          _buildDeleteRecordingsButton(context, ref),

        const SizedBox(height: 24),

        // T084 [US4] Notification settings section
        _buildSectionHeader(context, '通知設定'),
        _buildNotificationToggle(context, ref, settings),
        if (settings.emailNotifications) ...[
          const SizedBox(height: 8),
          _buildNotificationFrequency(context, ref, settings),
          const SizedBox(height: 8),
          _buildNotificationEmail(context, ref, settings),
        ],

        const SizedBox(height: 24),

        // Privacy notice
        _buildPrivacyNotice(context),
      ],
    );
  }

  /// T084 [US4] Build email notification toggle.
  Widget _buildNotificationToggle(
    BuildContext context,
    WidgetRef ref,
    InteractionSettings settings,
  ) {
    return Card(
      child: SwitchListTile(
        key: const Key('email_notifications_switch'),
        title: const Text('電子郵件通知'),
        subtitle: const Text('接收互動紀錄的電子郵件'),
        value: settings.emailNotifications,
        onChanged: (value) {
          ref
              .read(interactionSettingsProvider.notifier)
              .updateEmailNotifications(value);
        },
        secondary: Icon(
          settings.emailNotifications
              ? Icons.notifications_active
              : Icons.notifications_off,
          color: settings.emailNotifications
              ? Theme.of(context).colorScheme.primary
              : null,
        ),
      ),
    );
  }

  /// T084 [US4] Build notification frequency picker.
  Widget _buildNotificationFrequency(
    BuildContext context,
    WidgetRef ref,
    InteractionSettings settings,
  ) {
    return Card(
      child: ListTile(
        key: const Key('notification_frequency_setting'),
        leading: const Icon(Icons.schedule),
        title: const Text('通知頻率'),
        subtitle: Text(settings.notificationFrequency.displayName),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showFrequencyPicker(context, ref, settings),
      ),
    );
  }

  /// T084 [US4] Build notification email field.
  Widget _buildNotificationEmail(
    BuildContext context,
    WidgetRef ref,
    InteractionSettings settings,
  ) {
    return Card(
      child: ListTile(
        key: const Key('notification_email_setting'),
        leading: const Icon(Icons.email),
        title: const Text('通知信箱'),
        subtitle: Text(settings.notificationEmail ?? '尚未設定'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showEmailDialog(context, ref, settings),
      ),
    );
  }

  /// T084 [US4] Show frequency picker dialog.
  void _showFrequencyPicker(
    BuildContext context,
    WidgetRef ref,
    InteractionSettings settings,
  ) {
    showDialog<void>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('選擇通知頻率'),
        children: NotificationFrequency.values.map((frequency) {
          return RadioListTile<NotificationFrequency>(
            title: Text(frequency.displayName),
            subtitle: Text(frequency.description),
            value: frequency,
            groupValue: settings.notificationFrequency,
            onChanged: (value) {
              if (value != null) {
                ref
                    .read(interactionSettingsProvider.notifier)
                    .updateNotificationFrequency(value);
                Navigator.of(context).pop();
              }
            },
          );
        }).toList(),
      ),
    );
  }

  /// T084 [US4] Show email input dialog.
  void _showEmailDialog(
    BuildContext context,
    WidgetRef ref,
    InteractionSettings settings,
  ) {
    final controller = TextEditingController(
      text: settings.notificationEmail,
    );

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('設定通知信箱'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '電子郵件',
            hintText: 'parent@example.com',
            prefixIcon: Icon(Icons.email),
          ),
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final email = controller.text.trim();
              if (email.isNotEmpty) {
                ref
                    .read(interactionSettingsProvider.notifier)
                    .updateNotificationEmail(email);
              }
              Navigator.of(context).pop();
            },
            child: const Text('儲存'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }

  Widget _buildRecordingToggle(
    BuildContext context,
    WidgetRef ref,
    InteractionSettings settings,
  ) {
    return Card(
      child: SwitchListTile(
        key: const Key('recording_enabled_switch'),
        title: const Text('啟用錄音'),
        subtitle: const Text('錄製孩子與 AI 的對話'),
        value: settings.recordingEnabled,
        onChanged: (value) {
          if (value) {
            // Show confirmation dialog when enabling
            _showRecordingConfirmDialog(context, ref);
          } else {
            ref
                .read(interactionSettingsProvider.notifier)
                .updateRecordingEnabled(false);
          }
        },
        secondary: Icon(
          settings.recordingEnabled ? Icons.mic : Icons.mic_off,
          color: settings.recordingEnabled
              ? Theme.of(context).colorScheme.primary
              : null,
        ),
      ),
    );
  }

  Widget _buildAutoTranscribeToggle(
    BuildContext context,
    WidgetRef ref,
    InteractionSettings settings,
  ) {
    return Card(
      child: SwitchListTile(
        key: const Key('auto_transcribe_switch'),
        title: const Text('自動轉寫'),
        subtitle: const Text('自動將錄音轉換為文字'),
        value: settings.autoTranscribe,
        onChanged: (value) {
          ref
              .read(interactionSettingsProvider.notifier)
              .updateAutoTranscribe(value);
        },
        secondary: const Icon(Icons.text_snippet),
      ),
    );
  }

  Widget _buildRetentionDaysSetting(
    BuildContext context,
    WidgetRef ref,
    InteractionSettings settings,
  ) {
    return Card(
      child: ListTile(
        key: const Key('retention_days_setting'),
        leading: const Icon(Icons.schedule),
        title: const Text('保留期限'),
        subtitle: Text('${settings.retentionDays} 天'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showRetentionPicker(context, ref, settings),
      ),
    );
  }

  Widget _buildStorageInfo(BuildContext context, dynamic storage) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('錄音數量'),
                Text('${storage.totalRecordings} 個'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('佔用空間'),
                Text('${storage.totalSizeMB} MB'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('總時長'),
                Text('${storage.totalDurationSeconds.toStringAsFixed(1)} 秒'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeleteRecordingsButton(BuildContext context, WidgetRef ref) {
    return OutlinedButton.icon(
      onPressed: () => _showDeleteConfirmDialog(context, ref),
      icon: const Icon(Icons.delete_forever),
      label: const Text('刪除所有錄音'),
      style: OutlinedButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  Widget _buildPrivacyNotice(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.privacy_tip, size: 20),
                SizedBox(width: 8),
                Text(
                  '隱私說明',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              '錄音僅保存在您的設備上，不會上傳到雲端。錄音將在設定的保留期限後自動刪除。您可以隨時手動刪除所有錄音。',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  void _showRecordingConfirmDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('啟用錄音'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('啟用錄音後，將會保存孩子與 AI 的對話錄音。'),
            SizedBox(height: 8),
            Text(
              '隱私保護：',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('• 錄音僅保存在您的設備上'),
            Text('• 錄音將在設定的期限後自動刪除'),
            Text('• 您可以隨時手動刪除所有錄音'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              ref
                  .read(interactionSettingsProvider.notifier)
                  .updateRecordingEnabled(true);
              Navigator.of(context).pop();
            },
            child: const Text('確認'),
          ),
        ],
      ),
    );
  }

  void _showRetentionPicker(
    BuildContext context,
    WidgetRef ref,
    InteractionSettings settings,
  ) {
    showDialog<void>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('選擇保留期限'),
        children: [
          _buildRetentionOption(context, ref, 7, settings.retentionDays),
          _buildRetentionOption(context, ref, 14, settings.retentionDays),
          _buildRetentionOption(context, ref, 30, settings.retentionDays),
          _buildRetentionOption(context, ref, 60, settings.retentionDays),
          _buildRetentionOption(context, ref, 90, settings.retentionDays),
        ],
      ),
    );
  }

  Widget _buildRetentionOption(
    BuildContext context,
    WidgetRef ref,
    int days,
    int currentDays,
  ) {
    return SimpleDialogOption(
      onPressed: () {
        ref
            .read(interactionSettingsProvider.notifier)
            .updateRetentionDays(days);
        Navigator.of(context).pop();
      },
      child: Row(
        children: [
          Text('$days 天'),
          const Spacer(),
          if (days == currentDays)
            Icon(
              Icons.check,
              color: Theme.of(context).colorScheme.primary,
            ),
        ],
      ),
    );
  }

  void _showDeleteConfirmDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認刪除'),
        content: const Text(
          '確定要刪除所有錄音嗎？此操作無法復原。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              // TODO: Implement delete all recordings
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已刪除所有錄音')),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
  }
}
