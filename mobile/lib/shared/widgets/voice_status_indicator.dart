import 'package:flutter/material.dart';

import '../../core/database/enums.dart';

/// A compact widget that displays the current voice profile status.
///
/// Shows an icon and text label indicating whether a voice profile
/// has been recorded, is being processed, or is ready to use.
class VoiceStatusIndicator extends StatelessWidget {
  const VoiceStatusIndicator({
    super.key,
    required this.status,
    this.iconSize = 16,
    this.fontSize = 12,
  });

  /// The voice profile status to display.
  /// If null, shows "尚未錄製" (not recorded).
  final VoiceProfileStatus? status;

  /// Size of the status icon.
  final double iconSize;

  /// Font size for the status text.
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final (icon, label, color) = _getStatusDisplay();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: iconSize,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            color: color,
          ),
        ),
      ],
    );
  }

  (IconData, String, Color) _getStatusDisplay() {
    return switch (status) {
      null => (Icons.mic_off, '尚未錄製', Colors.grey),
      VoiceProfileStatus.pending => (Icons.hourglass_empty, '準備中', Colors.orange),
      VoiceProfileStatus.processing => (Icons.sync, '處理中', Colors.orange),
      VoiceProfileStatus.ready => (Icons.check_circle, '已就緒', Colors.green),
      VoiceProfileStatus.failed => (Icons.error, '處理失敗', Colors.red),
    };
  }
}
