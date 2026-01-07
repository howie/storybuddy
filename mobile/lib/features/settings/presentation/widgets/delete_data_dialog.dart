import 'package:flutter/material.dart';

import '../../../../app/theme.dart';

/// Dialog for confirming local data deletion.
class DeleteDataDialog extends StatefulWidget {
  const DeleteDataDialog({
    required this.onConfirm,
    super.key,
  });

  final Future<void> Function() onConfirm;

  @override
  State<DeleteDataDialog> createState() => _DeleteDataDialogState();
}

class _DeleteDataDialogState extends State<DeleteDataDialog> {
  bool _isDeleting = false;
  bool _confirmed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      icon: Icon(
        Icons.warning_amber_rounded,
        size: 48,
        color: theme.colorScheme.error,
      ),
      title: const Text('清除本機資料'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '此操作將刪除以下資料：',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 12),
          _DataItem(
            icon: Icons.auto_stories,
            text: '所有快取的故事',
          ),
          _DataItem(
            icon: Icons.audiotrack,
            text: '所有快取的語音檔案',
          ),
          _DataItem(
            icon: Icons.chat,
            text: '所有 Q&A 記錄',
          ),
          _DataItem(
            icon: Icons.help_outline,
            text: '所有待回答問題',
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 18,
                  color: theme.colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '帳號資料不會受影響，您仍可重新同步資料。',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          CheckboxListTile(
            value: _confirmed,
            onChanged: _isDeleting
                ? null
                : (value) {
                    setState(() {
                      _confirmed = value ?? false;
                    });
                  },
            title: Text(
              '我了解此操作無法復原',
              style: AppTextStyles.labelLarge,
            ),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isDeleting ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _confirmed && !_isDeleting
              ? () async {
                  setState(() {
                    _isDeleting = true;
                  });

                  try {
                    await widget.onConfirm();
                  } finally {
                    if (mounted) {
                      setState(() {
                        _isDeleting = false;
                      });
                    }
                  }
                }
              : null,
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
          ),
          child: _isDeleting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('清除資料'),
        ),
      ],
    );
  }
}

class _DataItem extends StatelessWidget {
  const _DataItem({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: AppTextStyles.labelLarge.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
