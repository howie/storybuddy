import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'package:storybuddy/features/interaction/domain/entities/interaction_transcript.dart';

/// T083 [US4] Implement share transcript feature.
///
/// Bottom sheet for sharing transcript via various methods.
class ShareTranscriptSheet extends StatelessWidget {
  const ShareTranscriptSheet({
    required this.transcript, super.key,
    this.onEmailTap,
  });

  final InteractionTranscript transcript;
  final VoidCallback? onEmailTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  '分享互動紀錄',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.share),
            title: const Text('分享為文字'),
            subtitle: const Text('透過其他 App 分享'),
            onTap: () => _shareAsText(context),
          ),
          ListTile(
            leading: const Icon(Icons.copy),
            title: const Text('複製到剪貼簿'),
            subtitle: const Text('複製純文字內容'),
            onTap: () => _copyToClipboard(context),
          ),
          if (onEmailTap != null)
            ListTile(
              leading: const Icon(Icons.email),
              title: const Text('寄送電子郵件'),
              subtitle: const Text('寄送格式化的紀錄'),
              onTap: () {
                Navigator.pop(context);
                onEmailTap!();
              },
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _shareAsText(BuildContext context) async {
    final storyTitle = transcript.storyTitle ?? '互動故事';
    final text = '''
$storyTitle - 互動紀錄

時間：${transcript.createdAt}
時長：${transcript.durationText}
對話回合：${transcript.turnCount}

---

${transcript.plainText}

---
由 StoryBuddy 產生
''';

    Navigator.pop(context);
    await Share.share(
      text,
      subject: '$storyTitle - 互動紀錄',
    );
  }

  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: transcript.plainText));
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已複製到剪貼簿')),
    );
  }
}

/// Show the share transcript bottom sheet.
void showShareTranscriptSheet(
  BuildContext context, {
  required InteractionTranscript transcript,
  VoidCallback? onEmailTap,
}) {
  showModalBottomSheet(
    context: context,
    builder: (context) => ShareTranscriptSheet(
      transcript: transcript,
      onEmailTap: onEmailTap,
    ),
  );
}
