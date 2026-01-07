import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../domain/entities/qa_session.dart';
import '../providers/qa_session_provider.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/voice_input_button.dart';

/// Page for Q&A session after story playback.
class QASessionPage extends ConsumerStatefulWidget {
  const QASessionPage({
    required this.storyId,
    super.key,
  });

  final String storyId;

  @override
  ConsumerState<QASessionPage> createState() => _QASessionPageState();
}

class _QASessionPageState extends ConsumerState<QASessionPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Start session when page opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(qASessionNotifierProvider(widget.storyId).notifier)
          .startSession();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(qASessionNotifierProvider(widget.storyId));

    // Scroll to bottom when messages change
    ref.listen(qASessionNotifierProvider(widget.storyId), (prev, next) {
      if (prev?.messages.length != next.messages.length) {
        _scrollToBottom();
      }
    });

    // Show error snackbar
    if (sessionState.errorMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(sessionState.errorMessage!),
            action: SnackBarAction(
              label: '關閉',
              onPressed: () {
                ref
                    .read(qASessionNotifierProvider(widget.storyId).notifier)
                    .clearError();
              },
            ),
          ),
        );
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('故事問答'),
        actions: [
          if (sessionState.session != null)
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () => _showSessionInfo(sessionState.session!),
            ),
        ],
      ),
      body: _buildBody(sessionState),
    );
  }

  Widget _buildBody(QASessionUIState sessionState) {
    switch (sessionState.state) {
      case QASessionState.initial:
      case QASessionState.loading:
        return const LoadingIndicator();

      case QASessionState.error:
        if (sessionState.session == null) {
          return AppErrorWidget(
            message: sessionState.errorMessage ?? '無法開始問答',
            onRetry: () {
              ref
                  .read(qASessionNotifierProvider(widget.storyId).notifier)
                  .startSession();
            },
          );
        }
        // Fall through to active state if we have a session
        continue active;

      active:
      case QASessionState.active:
      case QASessionState.recording:
      case QASessionState.processing:
        return _buildSessionContent(sessionState);

      case QASessionState.ended:
        return _buildEndedState(sessionState);
    }
  }

  Widget _buildSessionContent(QASessionUIState sessionState) {
    final voiceService = ref.watch(voiceInputServiceProvider);
    final isRecording = sessionState.state == QASessionState.recording;
    final isProcessing = sessionState.state == QASessionState.processing;

    return Column(
      children: [
        // Limit warning banner
        if (sessionState.isNearLimit && !sessionState.hasReachedLimit)
          _buildLimitWarningBanner(sessionState),

        // Message list
        Expanded(
          child: sessionState.messages.isEmpty
              ? _buildWelcomeMessage()
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  itemCount: sessionState.messages.length +
                      (isProcessing ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == sessionState.messages.length && isProcessing) {
                      return const TypingIndicator();
                    }

                    final message = sessionState.messages[index];
                    return ChatBubble(
                      message: message,
                      onPlayAudio: message.hasAudio ? () {} : null,
                    );
                  },
                ),
        ),

        // Voice input area
        _buildInputArea(
          isRecording: isRecording,
          isProcessing: isProcessing,
          hasReachedLimit: sessionState.hasReachedLimit,
          amplitudeStream: voiceService.amplitudeStream,
        ),
      ],
    );
  }

  Widget _buildWelcomeMessage() {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: theme.colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Text(
              '故事聽完了！',
              style: AppTextStyles.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '有什麼問題想問嗎？\n點擊下方麥克風開始提問',
              style: AppTextStyles.bodyMedium.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLimitWarningBanner(QASessionUIState sessionState) {
    final theme = Theme.of(context);
    final remaining = sessionState.session?.remainingMessages ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.tertiaryContainer,
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 16,
            color: theme.colorScheme.onTertiaryContainer,
          ),
          const SizedBox(width: 8),
          Text(
            '還可以問 $remaining 個問題',
            style: AppTextStyles.labelLarge.copyWith(
              color: theme.colorScheme.onTertiaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea({
    required bool isRecording,
    required bool isProcessing,
    required bool hasReachedLimit,
    Stream<double>? amplitudeStream,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasReachedLimit) ...[
              _buildLimitReachedMessage(),
            ] else ...[
              VoiceInputButton(
                isRecording: isRecording,
                enabled: !isProcessing,
                amplitudeStream: amplitudeStream,
                onStartRecording: () {
                  ref
                      .read(qASessionNotifierProvider(widget.storyId).notifier)
                      .startRecording();
                },
                onStopRecording: () {
                  ref
                      .read(qASessionNotifierProvider(widget.storyId).notifier)
                      .stopRecordingAndSend();
                },
                onCancelRecording: () {
                  ref
                      .read(qASessionNotifierProvider(widget.storyId).notifier)
                      .cancelRecording();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLimitReachedMessage() {
    final theme = Theme.of(context);

    return Column(
      children: [
        Icon(
          Icons.check_circle,
          size: 48,
          color: theme.colorScheme.tertiary,
        ),
        const SizedBox(height: 16),
        Text(
          '今天的問答時間結束了！',
          style: AppTextStyles.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          '你問了很多好問題，明天再來吧！',
          style: AppTextStyles.bodyMedium.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () {
            ref
                .read(qASessionNotifierProvider(widget.storyId).notifier)
                .endSession();
            context.pop();
          },
          child: const Text('結束問答'),
        ),
      ],
    );
  }

  Widget _buildEndedState(QASessionUIState sessionState) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.celebration,
              size: 64,
              color: theme.colorScheme.tertiary,
            ),
            const SizedBox(height: 24),
            Text(
              '問答結束了！',
              style: AppTextStyles.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '你問了 ${sessionState.messages.length ~/ 2} 個問題',
              style: AppTextStyles.bodyMedium.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.pop(),
              child: const Text('返回故事'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSessionInfo(QASession session) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('問答資訊'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('狀態：${session.statusLabel}'),
            const SizedBox(height: 8),
            Text('已問問題：${session.messageCount ~/ 2} / ${QASession.maxMessages ~/ 2}'),
            const SizedBox(height: 8),
            Text('開始時間：${_formatTime(session.startedAt)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('關閉'),
          ),
          if (session.isActive)
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                ref
                    .read(qASessionNotifierProvider(widget.storyId).notifier)
                    .endSession();
              },
              child: const Text('結束問答'),
            ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
