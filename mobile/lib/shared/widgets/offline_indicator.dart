import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/connectivity_service.dart';

/// A banner widget that displays when the device is offline.
///
/// Shows a warning banner at the top of the screen when there's no
/// network connectivity. Automatically hides when connection is restored.
class OfflineIndicator extends ConsumerWidget {
  const OfflineIndicator({super.key, this.child});

  /// The child widget to wrap with the offline indicator.
  final Widget? child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivityAsync = ref.watch(isConnectedProvider);

    return connectivityAsync.when(
      data: (isConnected) {
        if (isConnected) {
          return child ?? const SizedBox.shrink();
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _OfflineBanner(),
            if (child != null) Expanded(child: child!),
          ],
        );
      },
      loading: () => child ?? const SizedBox.shrink(),
      error: (_, __) => child ?? const SizedBox.shrink(),
    );
  }
}

/// Internal banner widget showing offline status.
class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.errorContainer,
      child: SafeArea(
        bottom: false,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          child: Row(
            children: [
              Icon(
                Icons.cloud_off,
                size: 18,
                color: colorScheme.onErrorContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '目前處於離線狀態',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onErrorContainer,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(
                Icons.info_outline,
                size: 16,
                color: colorScheme.onErrorContainer.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small offline badge that can be shown next to items.
///
/// Use this for individual items like story cards to indicate
/// they require network connectivity.
class OfflineBadge extends StatelessWidget {
  const OfflineBadge({
    super.key,
    this.size = 16,
    this.showLabel = false,
  });

  /// Size of the badge icon.
  final double size;

  /// Whether to show a text label next to the icon.
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (showLabel) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off,
            size: size,
            color: colorScheme.outline,
          ),
          const SizedBox(width: 4),
          Text(
            '離線',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.outline,
            ),
          ),
        ],
      );
    }

    return Icon(
      Icons.cloud_off,
      size: size,
      color: colorScheme.outline,
    );
  }
}

/// Provider-based offline badge that only shows when offline.
class ConnectivityAwareOfflineBadge extends ConsumerWidget {
  const ConnectivityAwareOfflineBadge({
    super.key,
    this.size = 16,
    this.showLabel = false,
  });

  /// Size of the badge icon.
  final double size;

  /// Whether to show a text label next to the icon.
  final bool showLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivityAsync = ref.watch(isConnectedProvider);

    return connectivityAsync.when(
      data: (isConnected) {
        if (isConnected) return const SizedBox.shrink();
        return OfflineBadge(size: size, showLabel: showLabel);
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
