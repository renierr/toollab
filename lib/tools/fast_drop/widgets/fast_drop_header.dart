import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/tool_back_button.dart';

/// Title row of the fullscreen page: back button, name, connection state, and
/// the refresh action once there is a server to refresh from.
class FastDropHeader extends StatelessWidget {
  final bool isConfigured;
  final bool syncEnabled;
  final bool isServerAvailable;
  final bool isLoading;
  final VoidCallback onRefresh;

  const FastDropHeader({
    super.key,
    required this.isConfigured,
    required this.syncEnabled,
    required this.isServerAvailable,
    required this.isLoading,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final status = !isConfigured
        ? l10n.fastDropStatusNotConfigured
        : !syncEnabled
        ? l10n.fastDropStatusSyncDisabled
        : isServerAvailable
        ? l10n.fastDropStatusOnline
        : l10n.fastDropStatusOffline;

    final statusColor = !isConfigured
        ? theme.colorScheme.onSurface.withValues(alpha: 0.5)
        : !syncEnabled
        ? AppTheme.statusAmber
        : isServerAvailable
        ? AppTheme.statusGreen
        : AppTheme.statusRed;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          const ToolBackButton(),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.fastDropTitle,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  status,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          if (isConfigured && syncEnabled)
            IconButton(
              icon: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.accentTeal,
                      ),
                    )
                  : const Icon(Icons.refresh),
              tooltip: l10n.fastDropRefreshList,
              onPressed: onRefresh,
            ),
        ],
      ),
    );
  }
}
