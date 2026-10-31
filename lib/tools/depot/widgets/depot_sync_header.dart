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
    final now = DateTime.now();
    DateTime? latestQuote;
    for (final holding in state.holdings) {
      final quote = holding.quoteAt;
      if (!holding.isSold &&
          quote != null &&
          (latestQuote == null || quote.isAfter(latestQuote))) {
        latestQuote = quote;
      }
    }

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
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  lastSync == null
                      ? l10n.depotNeverSynced
                      : '${l10n.depotLastSync(FormatHelper.dateTime(lastSync))}'
                            '${now.difference(lastSync) > const Duration(hours: 24) ? ' · ${l10n.depotSyncStale}' : ''}',
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
        if (state.hasData)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              latestQuote == null
                  ? l10n.depotQuoteUnknown
                  : l10n.depotQuoteFreshness(
                      FormatHelper.dateTime(latestQuote),
                      now.difference(latestQuote) > const Duration(hours: 24)
                          ? l10n.depotQuoteStale
                          : l10n.depotQuoteRecent,
                    ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
              ),
            ),
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
