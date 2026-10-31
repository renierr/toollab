import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../depot_portfolio_labels.dart';
import '../parqet/parqet_exception.dart';
import 'depot_error_details_dialog.dart';

class DepotSyncErrorCard extends StatelessWidget {
  final ParqetException error;
  final VoidCallback? onRetry;
  final VoidCallback? onReconnect;

  const DepotSyncErrorCard({
    super.key,
    required this.error,
    this.onRetry,
    this.onReconnect,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final foreground = theme.colorScheme.onErrorContainer;

    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline, color: foreground),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      DepotPortfolioLabels.error(l10n, error),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: foreground,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              children: [
                TextButton(
                  onPressed: () => DepotErrorDetailsDialog.show(context, error),
                  style: TextButton.styleFrom(foregroundColor: foreground),
                  child: Text(l10n.depotErrorDetails),
                ),
                if (onReconnect != null)
                  TextButton(
                    onPressed: onReconnect,
                    style: TextButton.styleFrom(foregroundColor: foreground),
                    child: Text(l10n.depotSettingsReconnect),
                  )
                else if (onRetry != null)
                  TextButton(
                    onPressed: onRetry,
                    style: TextButton.styleFrom(foregroundColor: foreground),
                    child: Text(l10n.commonRetry),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
