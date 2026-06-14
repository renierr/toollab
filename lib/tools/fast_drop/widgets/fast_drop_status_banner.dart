import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tool_lab/theme/theme.dart';
import '../fast_drop_state.dart';

class FastDropStatusBanner extends StatelessWidget {
  final FastDropState appState;
  final VoidCallback onRetry;

  const FastDropStatusBanner({
    super.key,
    required this.appState,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final error = appState.fastDropError;

    if (error == null || appState.isServerAvailable) {
      return const SizedBox();
    }

    final isSyncDisabled = error == 'Cloud sync is disabled.';
    final isNotConfigured =
        error ==
        'Sync Server URL is not configured. Please configure it in settings.';

    if (isSyncDisabled) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.statusAmber.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.statusAmber, width: 1),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.warning_amber_outlined,
              color: AppTheme.statusAmber,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cloud Sync is Disabled',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Fast Drop requires cloud sync to be enabled in settings.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => context.push('/sync-settings'),
              child: const Text('Enable'),
            ),
          ],
        ),
      );
    }

    if (isNotConfigured) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.statusAmber.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.statusAmber, width: 1),
        ),
        child: Row(
          children: [
            const Icon(Icons.settings_outlined, color: AppTheme.statusAmber),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Not Configured',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Configure server URL in Cloud settings first.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => context.push('/sync-settings'),
              child: const Text('Settings'),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.statusRed.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.statusRed, width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_outlined, color: AppTheme.statusRed),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sync Server Unreachable',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  error,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.statusRed),
            tooltip: 'Retry Connection',
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}
