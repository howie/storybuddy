import 'package:flutter/material.dart';

/// T097 [P] Connection status widget for WebSocket state visualization.
///
/// Shows connection status, reconnection attempts, and error states
/// with appropriate visual feedback.
class ConnectionStatusWidget extends StatelessWidget {
  const ConnectionStatusWidget({
    required this.isConnected,
    required this.isReconnecting,
    this.reconnectAttempts = 0,
    this.maxReconnectAttempts = 5,
    this.errorMessage,
    this.onRetry,
    this.onDismiss,
    super.key,
  });

  final bool isConnected;
  final bool isReconnecting;
  final int reconnectAttempts;
  final int maxReconnectAttempts;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    // Don't show anything if connected and no error
    if (isConnected && errorMessage == null) {
      return const SizedBox.shrink();
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (isReconnecting) {
      return _buildReconnectingBanner(context);
    }

    if (errorMessage != null) {
      return _buildErrorBanner(context);
    }

    if (!isConnected) {
      return _buildDisconnectedBanner(context);
    }

    return const SizedBox.shrink();
  }

  Widget _buildReconnectingBanner(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      key: const ValueKey('reconnecting'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: theme.colorScheme.onTertiaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '正在重新連線...',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onTertiaryContainer,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '嘗試 $reconnectAttempts / $maxReconnectAttempts',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color:
                        theme.colorScheme.onTertiaryContainer.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          // Progress indicator
          SizedBox(
            width: 40,
            child: LinearProgressIndicator(
              value: reconnectAttempts / maxReconnectAttempts,
              backgroundColor:
                  theme.colorScheme.onTertiaryContainer.withOpacity(0.2),
              color: theme.colorScheme.onTertiaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisconnectedBanner(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      key: const ValueKey('disconnected'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.cloud_off,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '連線已中斷',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: const Text('重新連線'),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      key: const ValueKey('error'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            size: 20,
            color: theme.colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              errorMessage!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
          if (onDismiss != null)
            IconButton(
              icon: Icon(
                Icons.close,
                size: 18,
                color: theme.colorScheme.onErrorContainer,
              ),
              onPressed: onDismiss,
              visualDensity: VisualDensity.compact,
            ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: Text(
                '重試',
                style: TextStyle(color: theme.colorScheme.onErrorContainer),
              ),
            ),
        ],
      ),
    );
  }
}

/// T097 [P] Loading overlay for session initialization.
class SessionLoadingOverlay extends StatelessWidget {
  const SessionLoadingOverlay({
    required this.message,
    this.progress,
    super.key,
  });

  final String message;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ColoredBox(
      color: Colors.black54,
      child: Center(
        child: Card(
          margin: const EdgeInsets.all(32),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (progress != null)
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 4,
                    ),
                  )
                else
                  const SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(strokeWidth: 4),
                  ),
                const SizedBox(height: 24),
                Text(
                  message,
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                if (progress != null) ...[
                  const SizedBox(height: 16),
                  LinearProgressIndicator(value: progress),
                  const SizedBox(height: 8),
                  Text(
                    '${(progress! * 100).toInt()}%',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// T097 [P] Error dialog for critical errors.
class InteractionErrorDialog extends StatelessWidget {
  const InteractionErrorDialog({
    required this.title,
    required this.message,
    this.isRecoverable = true,
    this.onRetry,
    this.onDismiss,
    super.key,
  });

  final String title;
  final String message;
  final bool isRecoverable;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      icon: Icon(
        isRecoverable ? Icons.warning_amber_rounded : Icons.error_rounded,
        color: isRecoverable
            ? theme.colorScheme.tertiary
            : theme.colorScheme.error,
        size: 48,
      ),
      title: Text(title),
      content: Text(message),
      actions: [
        if (onDismiss != null)
          TextButton(
            onPressed: onDismiss,
            child: const Text('關閉'),
          ),
        if (isRecoverable && onRetry != null)
          FilledButton(
            onPressed: onRetry,
            child: const Text('重試'),
          ),
      ],
    );
  }

  /// Show the error dialog.
  static Future<void> show(
    BuildContext context, {
    required String title,
    required String message,
    bool isRecoverable = true,
    VoidCallback? onRetry,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: isRecoverable,
      builder: (context) => InteractionErrorDialog(
        title: title,
        message: message,
        isRecoverable: isRecoverable,
        onRetry: () {
          Navigator.of(context).pop();
          onRetry?.call();
        },
        onDismiss: () => Navigator.of(context).pop(),
      ),
    );
  }
}
