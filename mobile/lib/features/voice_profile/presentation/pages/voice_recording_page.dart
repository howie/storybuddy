import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme.dart';
import '../../../../shared/widgets/permission_request.dart';
import '../../domain/entities/voice_profile.dart';
import '../providers/voice_profile_provider.dart';
import '../widgets/recording_timer.dart';
import '../widgets/waveform_visualizer.dart';

/// Page for recording voice samples for voice cloning.
class VoiceRecordingPage extends ConsumerStatefulWidget {
  const VoiceRecordingPage({super.key});

  @override
  ConsumerState<VoiceRecordingPage> createState() => _VoiceRecordingPageState();
}

class _VoiceRecordingPageState extends ConsumerState<VoiceRecordingPage> {
  bool _hasShownPrivacyConsent = false;
  bool _hasPermission = false;
  final TextEditingController _nameController = TextEditingController(
    text: '我的聲音',
  );

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _checkPermission() async {
    final service = ref.read(audioRecordingServiceProvider);
    final hasPermission = await service.hasPermission();
    setState(() {
      _hasPermission = hasPermission;
    });
  }

  Future<void> _requestPermission() async {
    final service = ref.read(audioRecordingServiceProvider);
    final hasPermission = await service.requestPermission();
    setState(() {
      _hasPermission = hasPermission;
    });
  }

  void _showPrivacyConsent() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('隱私聲明'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '在錄製聲音之前，請閱讀以下聲明：',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Text('• 您的聲音樣本將用於 AI 語音合成'),
              SizedBox(height: 8),
              Text('• 聲音數據將安全加密儲存'),
              SizedBox(height: 8),
              Text('• 您可以隨時刪除您的聲音資料'),
              SizedBox(height: 8),
              Text('• 聲音數據不會用於其他商業目的'),
              SizedBox(height: 16),
              Text(
                '點擊「同意」即表示您理解並接受上述條款。',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.pop();
            },
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _hasShownPrivacyConsent = true;
              });
            },
            child: const Text('同意'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recordingState = ref.watch(voiceRecordingNotifierProvider);

    // Show privacy consent on first load
    if (!_hasShownPrivacyConsent) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showPrivacyConsent();
      });
    }

    // Handle upload completion
    if (recordingState.state == RecordingState.uploaded &&
        recordingState.uploadedProfileId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.pushReplacement(
          '/voice-profiles/${recordingState.uploadedProfileId}/status',
        );
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('錄製聲音'),
        actions: [
          if (recordingState.state == RecordingState.recording)
            TextButton(
              onPressed: () {
                ref.read(voiceRecordingNotifierProvider.notifier).cancelRecording();
              },
              child: const Text('取消'),
            ),
        ],
      ),
      body: !_hasPermission
          ? MicrophonePermissionRequest(
              onGranted: () {
                setState(() {
                  _hasPermission = true;
                });
              },
              onDenied: () {
                context.pop();
              },
            )
          : _buildContent(recordingState),
    );
  }

  Widget _buildContent(VoiceRecordingState recordingState) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Expanded(
              child: _buildRecordingArea(recordingState),
            ),
            _buildBottomSection(recordingState),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingArea(VoiceRecordingState recordingState) {
    final service = ref.watch(audioRecordingServiceProvider);
    final isRecording = recordingState.state == RecordingState.recording;
    final isStopped = recordingState.state == RecordingState.stopped;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Instructions
        if (recordingState.state == RecordingState.initial) ...[
          Icon(
            Icons.record_voice_over,
            size: 80,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
          ),
          const SizedBox(height: 24),
          Text(
            '錄製您的聲音樣本',
            style: AppTextStyles.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '請用正常語速朗讀一段文字\n建議 30-60 秒',
            style: AppTextStyles.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],

        // Recording in progress
        if (isRecording) ...[
          WaveformVisualizer(
            amplitudeStream: service.amplitudeStream,
            isRecording: true,
          ),
          const SizedBox(height: 32),
          RecordingTimer(
            isRecording: true,
            onTick: (seconds) {
              ref
                  .read(voiceRecordingNotifierProvider.notifier)
                  .updateElapsedTime(seconds);
              // Auto-stop at max duration
              if (seconds >= VoiceProfile.maxDurationSeconds) {
                ref.read(voiceRecordingNotifierProvider.notifier).stopRecording();
              }
            },
          ),
        ],

        // Recording stopped
        if (isStopped) ...[
          Icon(
            Icons.check_circle,
            size: 80,
            color: Theme.of(context).colorScheme.tertiary,
          ),
          const SizedBox(height: 24),
          Text(
            '錄音完成',
            style: AppTextStyles.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '${recordingState.elapsedSeconds} 秒',
            style: AppTextStyles.headlineSmall.copyWith(
              color: Theme.of(context).colorScheme.tertiary,
            ),
          ),
          const SizedBox(height: 24),
          // Name input
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: '聲音名稱',
              hintText: '例如：爸爸的聲音',
              prefixIcon: Icon(Icons.label_outline),
            ),
          ),
        ],

        // Uploading
        if (recordingState.state == RecordingState.uploading) ...[
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            '正在上傳...',
            style: AppTextStyles.bodyMedium,
          ),
        ],

        // Error
        if (recordingState.state == RecordingState.error) ...[
          Icon(
            Icons.error_outline,
            size: 80,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 24),
          Text(
            recordingState.errorMessage ?? '發生錯誤',
            style: AppTextStyles.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _buildBottomSection(VoiceRecordingState recordingState) {
    final isRecording = recordingState.state == RecordingState.recording;
    final isStopped = recordingState.state == RecordingState.stopped;
    final isInitial = recordingState.state == RecordingState.initial;
    final isError = recordingState.state == RecordingState.error;
    final canStop =
        isRecording && recordingState.elapsedSeconds >= VoiceProfile.minDurationSeconds;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Record button
        if (isInitial || isError) ...[
          _RecordButton(
            onTap: () {
              ref.read(voiceRecordingNotifierProvider.notifier).startRecording();
            },
          ),
          const SizedBox(height: 16),
          Text(
            '點擊開始錄音',
            style: AppTextStyles.labelLarge,
          ),
        ],

        // Stop button
        if (isRecording) ...[
          _StopButton(
            enabled: canStop,
            onTap: canStop
                ? () {
                    ref.read(voiceRecordingNotifierProvider.notifier).stopRecording();
                  }
                : null,
          ),
          const SizedBox(height: 16),
          Text(
            canStop ? '點擊停止錄音' : '請繼續錄音...',
            style: AppTextStyles.labelLarge,
          ),
        ],

        // Upload/Retry buttons
        if (isStopped) ...[
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    ref.read(voiceRecordingNotifierProvider.notifier).reset();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('重新錄製'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    ref.read(voiceRecordingNotifierProvider.notifier).uploadRecording(
                          name: _nameController.text.trim().isEmpty
                              ? '我的聲音'
                              : _nameController.text.trim(),
                        );
                  },
                  icon: const Icon(Icons.cloud_upload),
                  label: const Text('上傳'),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _RecordButton extends StatelessWidget {
  const _RecordButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: theme.colorScheme.error,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.error.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          Icons.mic,
          size: 40,
          color: theme.colorScheme.onError,
        ),
      ),
    );
  }
}

class _StopButton extends StatelessWidget {
  const _StopButton({
    required this.enabled,
    required this.onTap,
  });

  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: enabled
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest,
          shape: BoxShape.circle,
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Icon(
          Icons.stop,
          size: 40,
          color: enabled
              ? theme.colorScheme.onPrimary
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
