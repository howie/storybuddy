import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// A widget that guides users to grant a permission.
class PermissionRequestWidget extends StatelessWidget {
  const PermissionRequestWidget({
    required this.permission,
    required this.title,
    required this.description,
    required this.icon,
    required this.onGranted,
    super.key,
    this.onDenied,
  });

  /// The permission to request.
  final Permission permission;

  /// Title of the permission request.
  final String title;

  /// Description explaining why the permission is needed.
  final String description;

  /// Icon representing the permission.
  final IconData icon;

  /// Callback when permission is granted.
  final VoidCallback onGranted;

  /// Callback when permission is denied.
  final VoidCallback? onDenied;

  Future<void> _requestPermission(BuildContext context) async {
    final status = await permission.request();

    if (status.isGranted) {
      onGranted();
    } else if (status.isPermanentlyDenied) {
      if (context.mounted) {
        _showSettingsDialog(context);
      }
    } else {
      onDenied?.call();
    }
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('需要權限'),
        content: Text(
          '$title 權限已被拒絕。請前往設定開啟權限。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('前往設定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 48,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => _requestPermission(context),
              icon: const Icon(Icons.check),
              label: const Text('授權'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onDenied,
              child: const Text('稍後再說'),
            ),
          ],
        ),
      ),
    );
  }
}

/// A widget specifically for microphone permission.
class MicrophonePermissionRequest extends StatelessWidget {
  const MicrophonePermissionRequest({
    required this.onGranted,
    super.key,
    this.onDenied,
  });

  final VoidCallback onGranted;
  final VoidCallback? onDenied;

  @override
  Widget build(BuildContext context) {
    return PermissionRequestWidget(
      permission: Permission.microphone,
      title: '需要麥克風權限',
      description: 'StoryBuddy 需要使用麥克風來錄製您的聲音，以便 AI 模仿您的聲音講故事。',
      icon: Icons.mic,
      onGranted: onGranted,
      onDenied: onDenied,
    );
  }
}
