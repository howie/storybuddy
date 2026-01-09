import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/database/enums.dart';
import '../../../../shared/widgets/voice_status_indicator.dart';
import '../../../voice_profile/domain/entities/voice_profile.dart';
import '../../../voice_profile/presentation/providers/voice_profile_provider.dart';

/// Navigation drawer for the StoryBuddy app.
///
/// Provides access to:
/// - Voice recording (錄製聲音)
/// - Pending questions (待答問題)
/// - Settings (設定)
///
/// Also displays the current voice profile status in the drawer header.
class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voiceProfilesAsync = ref.watch(voiceProfileListNotifierProvider);

    // Get the best voice profile status to display
    final voiceStatus = _getVoiceStatus(voiceProfilesAsync);

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildDrawerHeader(context, voiceStatus),
          _buildVoiceRecordingTile(context, voiceStatus),
          _buildPendingQuestionsTile(context),
          const Divider(),
          _buildSettingsTile(context),
        ],
      ),
    );
  }

  /// Extracts the voice profile status from the async value.
  /// Returns the status of the latest ready profile, or the latest profile's status.
  VoiceProfileStatus? _getVoiceStatus(
      AsyncValue<List<VoiceProfile>> voiceProfilesAsync) {
    final profiles = voiceProfilesAsync.valueOrNull;
    if (profiles == null || profiles.isEmpty) {
      return null;
    }

    // Try to find a ready profile first
    final readyProfile = profiles.where((p) => p.isReady).firstOrNull;
    if (readyProfile != null) {
      return readyProfile.status;
    }

    // Otherwise return the status of the latest profile
    final sorted = [...profiles]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted.first.status;
  }

  Widget _buildDrawerHeader(
      BuildContext context, VoiceProfileStatus? voiceStatus) {
    return DrawerHeader(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Icon(
            Icons.auto_stories,
            size: 48,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
          const SizedBox(height: 8),
          Text(
            'StoryBuddy',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
          ),
          const SizedBox(height: 4),
          VoiceStatusIndicator(status: voiceStatus),
        ],
      ),
    );
  }

  Widget _buildVoiceRecordingTile(
      BuildContext context, VoiceProfileStatus? voiceStatus) {
    return ListTile(
      leading: const Icon(Icons.mic),
      title: const Text('錄製聲音'),
      subtitle: Text(
        voiceStatus == null
            ? '錄製您的聲音來講故事'
            : voiceStatus == VoiceProfileStatus.ready
                ? '已有可用的聲音模型'
                : '管理您的聲音模型',
      ),
      onTap: () => _navigateTo(context, '/voice-profile'),
    );
  }

  Widget _buildPendingQuestionsTile(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.question_answer),
      title: const Text('待答問題'),
      subtitle: const Text('查看小朋友的問題'),
      onTap: () => _navigateTo(context, '/pending-questions'),
    );
  }

  Widget _buildSettingsTile(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.settings),
      title: const Text('設定'),
      subtitle: const Text('調整 App 設定'),
      onTap: () => _navigateTo(context, '/settings'),
    );
  }

  void _navigateTo(BuildContext context, String path) {
    // Close the drawer first
    Navigator.pop(context);
    // Then navigate
    context.push(path);
  }
}
