import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/helpers/format_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../depot_portfolio_state.dart';
import '../depot_store.dart';
import 'depot_settings_page.dart';
import 'depot_sync_error_card.dart';

/// Portfolio picker, sync status and the last sync error, shared by the
/// overview and activities tabs.
class DepotSyncHeader extends StatelessWidget {
  const DepotSyncHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = context.watch<DepotPortfolioState>();
    final error = state.error;
    final lastSync = state.lastSyncAt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          children: [
            if (state.portfolios.length > 1)
              DropdownButton<String>(
                value: state.scope,
                underline: const SizedBox.shrink(),
                onChanged: (scope) {
                  if (scope != null) state.setScope(scope);
                },
                items: [
                  DropdownMenuItem(
                    value: DepotStore.allScope,
                    child: Text(l10n.depotAllPortfolios),
                  ),
                  for (final p in state.portfolios)
                    DropdownMenuItem(value: p.id, child: Text(p.name)),
                ],
              )
            else if (state.portfolios.length == 1)
              Text(
                state.portfolios.first.name,
                style: theme.textTheme.titleSmall,
              ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  lastSync == null
                      ? l10n.depotNeverSynced
                      : l10n.depotLastSync(FormatHelper.dateTime(lastSync)),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
                const SizedBox(width: 4),
                state.isSyncing
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.sync_outlined),
                        tooltip: l10n.depotSyncNow,
                        onPressed: state.sync,
                      ),
              ],
            ),
          ],
        ),
        if (error != null)
          DepotSyncErrorCard(
            error: error,
            onRetry: state.sync,
            onReconnect: error.needsLogin
                ? () => DepotSettingsPage.open(context)
                : null,
          ),
      ],
    );
  }
}
