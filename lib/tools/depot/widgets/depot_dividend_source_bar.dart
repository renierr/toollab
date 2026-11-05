import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/helpers/format_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../depot_dividend_state.dart';

/// Where the dividend dates come from and when they were loaded.
class DepotDividendSourceBar extends StatelessWidget {
  const DepotDividendSourceBar({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = context.watch<DepotDividendState>();
    final fetchedAt = state.fetchedAt;
    final hint = theme.textTheme.bodySmall?.copyWith(color: theme.hintColor);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  fetchedAt == null
                      ? l10n.depotDividendSourceNever
                      : l10n.depotDividendSource(
                          FormatHelper.dateTime(fetchedAt),
                        ),
                  style: hint,
                ),
              ),
              if (state.isFetching)
                const SizedBox.square(
                  dimension: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          if (state.failedCount > 0)
            Text(
              l10n.depotDividendFailed(state.failedCount),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
        ],
      ),
    );
  }
}
