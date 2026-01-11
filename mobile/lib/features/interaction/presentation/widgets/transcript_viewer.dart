import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:storybuddy/features/interaction/domain/entities/interaction_transcript.dart';

/// T081 [US4] Create transcript viewer widget.
///
/// Displays a formatted interaction transcript with conversation turns.
class TranscriptViewer extends StatelessWidget {
  const TranscriptViewer({
    required this.transcript, super.key,
    this.onShare,
    this.onEmail,
  });

  final InteractionTranscript transcript;
  final VoidCallback? onShare;
  final VoidCallback? onEmail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with story title
          _buildHeader(context, theme),

          // Metadata
          _buildMetadata(context, theme),

          const Divider(height: 32),

          // Transcript content
          _buildTranscriptContent(context, theme),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  label: '互動紀錄：${transcript.storyTitle ?? "故事"}',
                  child: Text(
                    transcript.storyTitle ?? '互動紀錄',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              if (onShare != null)
                IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: onShare,
                  tooltip: '分享',
                ),
              if (onEmail != null)
                IconButton(
                  icon: const Icon(Icons.email),
                  onPressed: onEmail,
                  tooltip: '寄送電子郵件',
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            DateFormat('yyyy年M月d日 HH:mm').format(transcript.createdAt),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadata(BuildContext context, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        children: [
          _buildMetadataChip(
            context,
            icon: Icons.timer_outlined,
            label: transcript.durationText,
          ),
          _buildMetadataChip(
            context,
            icon: Icons.chat_outlined,
            label: '${transcript.turnCount} 回合',
          ),
          if (transcript.wasEmailed)
            _buildMetadataChip(
              context,
              icon: Icons.check_circle_outline,
              label: '已寄送',
              color: Colors.green,
            ),
        ],
      ),
    );
  }

  Widget _buildMetadataChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    Color? color,
  }) {
    final theme = Theme.of(context);
    final chipColor = color ?? theme.colorScheme.primary;

    return Chip(
      avatar: Icon(icon, size: 18, color: chipColor),
      label: Text(label),
      backgroundColor: chipColor.withOpacity(0.1),
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  Widget _buildTranscriptContent(BuildContext context, ThemeData theme) {
    if (transcript.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.chat_bubble_outline,
                size: 48,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                '（沒有對話紀錄）',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Parse the plain text into entries
    final entries = _parseTranscript(transcript.plainText);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children:
            entries.map((entry) => _buildEntry(context, theme, entry)).toList(),
      ),
    );
  }

  List<_TranscriptEntry> _parseTranscript(String plainText) {
    final entries = <_TranscriptEntry>[];
    final lines = plainText.split('\n');

    final timestampPattern = RegExp(r'^\[(\d+:\d{2})\]\s*(.+)：(.+)$');

    for (final line in lines) {
      if (line.trim().isEmpty) continue;

      final match = timestampPattern.firstMatch(line);
      if (match != null) {
        final timestamp = match.group(1)!;
        final speaker = match.group(2)!;
        final text = match.group(3)!;

        _SpeakerType speakerType;
        if (speaker.contains('孩子')) {
          speakerType = _SpeakerType.child;
        } else if (speaker.contains('AI') || speaker.contains('故事')) {
          speakerType = _SpeakerType.ai;
        } else {
          speakerType = _SpeakerType.system;
        }

        final wasInterrupted = text.contains('[中斷]') || text.contains('[打斷]');

        entries.add(_TranscriptEntry(
          timestamp: timestamp,
          speaker: speaker,
          speakerType: speakerType,
          text: text.replaceAll(RegExp(r'\s*\[中斷.*\]'), ''),
          wasInterrupted: wasInterrupted,
        ),);
      } else {
        // Non-timestamped line, treat as continuation or standalone
        entries.add(_TranscriptEntry(
          timestamp: '',
          speaker: '',
          speakerType: _SpeakerType.system,
          text: line,
        ),);
      }
    }

    return entries;
  }

  Widget _buildEntry(
    BuildContext context,
    ThemeData theme,
    _TranscriptEntry entry,
  ) {
    final isChild = entry.speakerType == _SpeakerType.child;
    final isAi = entry.speakerType == _SpeakerType.ai;

    Color backgroundColor;
    Color borderColor;
    String speakerLabel;
    IconData speakerIcon;

    if (isChild) {
      backgroundColor = Colors.green.shade50;
      borderColor = Colors.green.shade300;
      speakerLabel = '孩子';
      speakerIcon = Icons.child_care;
    } else if (isAi) {
      backgroundColor = Colors.blue.shade50;
      borderColor = Colors.blue.shade300;
      speakerLabel = 'AI';
      speakerIcon = Icons.smart_toy;
    } else {
      backgroundColor = Colors.orange.shade50;
      borderColor = Colors.orange.shade300;
      speakerLabel = '系統';
      speakerIcon = Icons.info_outline;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border(
            left: BorderSide(color: borderColor, width: 4),
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(speakerIcon, size: 16, color: borderColor),
                const SizedBox(width: 4),
                Text(
                  speakerLabel,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: borderColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (entry.wasInterrupted) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '中斷',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                if (entry.timestamp.isNotEmpty)
                  Text(
                    '[${entry.timestamp}]',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              entry.text,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

enum _SpeakerType { child, ai, system }

class _TranscriptEntry {
  const _TranscriptEntry({
    required this.timestamp,
    required this.speaker,
    required this.speakerType,
    required this.text,
    this.wasInterrupted = false,
  });

  final String timestamp;
  final String speaker;
  final _SpeakerType speakerType;
  final String text;
  final bool wasInterrupted;
}

/// Loading state widget for transcript viewer.
class TranscriptViewerLoading extends StatelessWidget {
  const TranscriptViewerLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: CircularProgressIndicator(),
      ),
    );
  }
}

/// Error state widget for transcript viewer.
class TranscriptViewerError extends StatelessWidget {
  const TranscriptViewerError({
    required this.message, required this.onRetry, super.key,
  });

  final String message;
  final VoidCallback onRetry;

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
              Icons.error_outline,
              size: 48,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('重試'),
            ),
          ],
        ),
      ),
    );
  }
}
