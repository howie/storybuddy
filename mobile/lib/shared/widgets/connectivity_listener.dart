import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/connectivity_service.dart';

/// A widget that listens to connectivity changes and shows snackbars.
///
/// Wrap your app or main content with this widget to get automatic
/// notifications when the device goes online or offline.
class ConnectivityListener extends ConsumerStatefulWidget {
  const ConnectivityListener({
    super.key,
    required this.child,
  });

  /// The child widget to render.
  final Widget child;

  @override
  ConsumerState<ConnectivityListener> createState() =>
      _ConnectivityListenerState();
}

class _ConnectivityListenerState extends ConsumerState<ConnectivityListener> {
  bool? _previousState;

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<bool>>(
      isConnectedProvider,
      (previous, next) {
        final wasConnected = previous?.valueOrNull ?? _previousState;
        final isConnected = next.valueOrNull;

        if (isConnected != null && wasConnected != null) {
          if (!isConnected && wasConnected) {
            // Just went offline
            _showOfflineSnackbar(context);
          } else if (isConnected && !wasConnected) {
            // Just came back online
            _showOnlineSnackbar(context);
          }
        }

        _previousState = isConnected;
      },
    );

    return widget.child;
  }

  void _showOfflineSnackbar(BuildContext context) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.cloud_off, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Text('您已離線，部分功能可能無法使用'),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.error,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showOnlineSnackbar(BuildContext context) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.cloud_done, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('已恢復連線'),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
