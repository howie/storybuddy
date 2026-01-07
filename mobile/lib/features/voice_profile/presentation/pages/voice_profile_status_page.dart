import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme.dart';
import '../../../../core/database/enums.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../domain/entities/voice_profile.dart';
import '../providers/voice_profile_provider.dart';

/// Page showing the status of a voice profile.
class VoiceProfileStatusPage extends ConsumerStatefulWidget {
  const VoiceProfileStatusPage({
    required this.profileId,
    super.key,
  });

  final String profileId;

  @override
  ConsumerState<VoiceProfileStatusPage> createState() =>
      _VoiceProfileStatusPageState();
}

class _VoiceProfileStatusPageState
    extends ConsumerState<VoiceProfileStatusPage> {
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    // Poll for status updates every 5 seconds while processing
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _refreshStatus();
    });
  }

  Future<void> _refreshStatus() async {
    try {
      final repository = ref.read(voiceProfileRepositoryProvider);
      await repository.refreshStatus(widget.profileId);
    } catch (_) {
      // Ignore refresh errors
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileStream = ref.watch(
      voiceProfileStreamProvider(widget.profileId),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('語音狀態'),
      ),
      body: profileStream.when(
        loading: () => const LoadingIndicator(),
        error: (error, stack) => AppErrorWidget(
          message: '無法載入語音狀態',
          onRetry: _refreshStatus,
        ),
        data: (profile) {
          if (profile == null) {
            return const AppErrorWidget(message: '找不到語音檔案');
          }

          // Stop polling when not processing
          if (profile.status != VoiceProfileStatus.processing) {
            _pollingTimer?.cancel();
          }

          return _buildContent(profile);
        },
      ),
    );
  }

  Widget _buildContent(VoiceProfile profile) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Expanded(
              child: _buildStatusSection(profile),
            ),
            _buildActionButtons(profile),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSection(VoiceProfile profile) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStatusIcon(profile),
        const SizedBox(height: 24),
        Text(
          profile.name,
          style: AppTextStyles.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        _buildStatusBadge(profile),
        const SizedBox(height: 24),
        _buildStatusDescription(profile),
        if (profile.sampleDurationSeconds != null) ...[
          const SizedBox(height: 16),
          Text(
            '錄音時長：${profile.sampleDurationSeconds} 秒',
            style: AppTextStyles.labelLarge.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatusIcon(VoiceProfile profile) {
    final theme = Theme.of(context);

    switch (profile.status) {
      case VoiceProfileStatus.pending:
        return Icon(
          Icons.cloud_upload_outlined,
          size: 80,
          color: theme.colorScheme.primary.withOpacity(0.5),
        );

      case VoiceProfileStatus.processing:
        return Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 100,
              height: 100,
              child: CircularProgressIndicator(
                strokeWidth: 4,
                color: theme.colorScheme.primary,
              ),
            ),
            Icon(
              Icons.auto_awesome,
              size: 48,
              color: theme.colorScheme.primary,
            ),
          ],
        );

      case VoiceProfileStatus.ready:
        return Icon(
          Icons.check_circle,
          size: 80,
          color: theme.colorScheme.tertiary,
        );

      case VoiceProfileStatus.failed:
        return Icon(
          Icons.error_outline,
          size: 80,
          color: theme.colorScheme.error,
        );
    }
  }

  Widget _buildStatusBadge(VoiceProfile profile) {
    final theme = Theme.of(context);

    Color backgroundColor;
    Color textColor;

    switch (profile.status) {
      case VoiceProfileStatus.pending:
        backgroundColor = theme.colorScheme.primaryContainer;
        textColor = theme.colorScheme.onPrimaryContainer;

      case VoiceProfileStatus.processing:
        backgroundColor = theme.colorScheme.secondaryContainer;
        textColor = theme.colorScheme.onSecondaryContainer;

      case VoiceProfileStatus.ready:
        backgroundColor = theme.colorScheme.tertiaryContainer;
        textColor = theme.colorScheme.onTertiaryContainer;

      case VoiceProfileStatus.failed:
        backgroundColor = theme.colorScheme.errorContainer;
        textColor = theme.colorScheme.onErrorContainer;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        profile.statusLabel,
        style: AppTextStyles.bodyMedium.copyWith(color: textColor),
      ),
    );
  }

  Widget _buildStatusDescription(VoiceProfile profile) {
    final theme = Theme.of(context);

    String description;

    switch (profile.status) {
      case VoiceProfileStatus.pending:
        description = '您的聲音樣本正在等待上傳';

      case VoiceProfileStatus.processing:
        description = 'AI 正在學習您的聲音特徵\n這可能需要幾分鐘時間';

      case VoiceProfileStatus.ready:
        description = '您的聲音已準備就緒！\n現在可以用您的聲音講故事了';

      case VoiceProfileStatus.failed:
        description = profile.errorMessage ?? '聲音處理失敗，請重新錄製';
    }

    return Text(
      description,
      style: AppTextStyles.bodyMedium.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildActionButtons(VoiceProfile profile) {
    switch (profile.status) {
      case VoiceProfileStatus.pending:
        return FilledButton.icon(
          onPressed: () async {
            try {
              final repository = ref.read(voiceProfileRepositoryProvider);
              await repository.uploadVoiceProfile(widget.profileId);
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('上傳失敗：$e')),
                );
              }
            }
          },
          icon: const Icon(Icons.cloud_upload),
          label: const Text('上傳'),
        );

      case VoiceProfileStatus.processing:
        return OutlinedButton(
          onPressed: () => context.pop(),
          child: const Text('稍後查看'),
        );

      case VoiceProfileStatus.ready:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton.icon(
              onPressed: () => context.go('/stories'),
              icon: const Icon(Icons.auto_stories),
              label: const Text('開始講故事'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.pop(),
              child: const Text('返回'),
            ),
          ],
        );

      case VoiceProfileStatus.failed:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton.icon(
              onPressed: () => context.pushReplacement('/voice-profiles/record'),
              icon: const Icon(Icons.refresh),
              label: const Text('重新錄製'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () async {
                final repository = ref.read(voiceProfileRepositoryProvider);
                await repository.deleteVoiceProfile(widget.profileId);
                if (mounted) {
                  context.pop();
                }
              },
              child: const Text('刪除'),
            ),
          ],
        );
    }
  }
}
