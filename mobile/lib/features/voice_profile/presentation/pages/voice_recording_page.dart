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
  bool _isDialogShowing = false;
  bool _hasPermission = false;
  final TextEditingController _nameController = TextEditingController(
    text: '我的聲音',
  );

  static const String _sampleText = '''
從前從前，在一個遙遠的森林盡頭，住著一位可愛的小女孩。因為她總是穿著外婆送給她的紅色連帽斗篷，所以大家都叫她「小紅帽」。

有一天，媽媽對小紅帽說：「外婆生病了，身體不太舒服。你幫我把這籃剛烤好的蛋糕和一瓶葡萄酒送去給外婆，讓她補補身子。」媽媽特別叮嚀說：「路上要小心，專心走路，不要在森林裡貪玩，也不要隨便跟陌生人說話喔。」

小紅帽乖巧地點點頭，答應了媽媽。她提著籃子，踏著輕快的步伐出門了。森林裡的空氣好清新，金色的陽光透過樹葉的縫隙灑在草地上，像是一顆顆發亮的寶石。五顏六色的野花開滿了路邊，小鳥也在枝頭開心地唱歌。小紅帽看著美麗的風景，心裡覺得好溫暖，忍不住開心地哼起了歌來。
''';

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

  Future<void> _showPrivacyConsent() async {
    if (_isDialogShowing) return;
    
    setState(() {
      _isDialogShowing = true;
    });

    final result = await showDialog<bool>(
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
              Navigator.pop(context, false);
            },
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context, true);
            },
            child: const Text('同意'),
          ),
        ],
      ),
    );

    if (mounted) {
      if (result == true) {
        setState(() {
          _hasShownPrivacyConsent = true;
          _isDialogShowing = false;
        });
      } else {
        // User cancelled
        context.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<VoiceRecordingState>(
      voiceRecordingNotifierProvider,
      (previous, next) {
        if (next.state == RecordingState.uploaded &&
            next.uploadedProfileId != null) {
          if (mounted) {
            context.pushReplacement(
              '/voice-profile/status/${next.uploadedProfileId}',
            );
          }
        }
      },
    );

    final recordingState = ref.watch(voiceRecordingNotifierProvider);

    // Show privacy consent on first load
    if (!_hasShownPrivacyConsent && !_isDialogShowing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showPrivacyConsent();
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
            size: 64,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            '錄製您的聲音樣本',
            style: AppTextStyles.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '請朗讀以下文字（約 45 秒）',
            style: AppTextStyles.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Expanded(child: _buildScriptCard()),
        ],

        // Recording in progress
        if (isRecording) ...[
          Expanded(child: _buildScriptCard()),
          const SizedBox(height: 16),
          SizedBox(
            height: 80,
            child: WaveformVisualizer(
              amplitudeStream: service.amplitudeStream,
              isRecording: true,
            ),
          ),
          const SizedBox(height: 16),
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
          const SizedBox(height: 16),
          CircularProgressIndicator(
            value: recordingState.uploadProgress > 0
                ? recordingState.uploadProgress
                : null,
          ),
          const SizedBox(height: 24),
          if (recordingState.uploadProgress > 0) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48.0),
              child: LinearProgressIndicator(
                value: recordingState.uploadProgress,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '正在上傳... ${(recordingState.uploadProgress * 100).toInt()}%',
              style: AppTextStyles.bodyMedium,
            ),
          ] else
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
          const SizedBox(height: 16),
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
          // Spacer/SizedBox handled in recording area
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

  Widget _buildScriptCard() {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Text(
          _sampleText,
          style: AppTextStyles.bodyLarge.copyWith(height: 1.8),
        ),
      ),
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
