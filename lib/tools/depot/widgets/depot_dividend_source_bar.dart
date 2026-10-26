import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/helpers/format_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../depot_dividend_state.dart';

/// Where the dividend dates come from, when they were loaded, and a reload.
class DepotDividendSourceBar extends StatelessWidget {
  final VoidCallback onRefresh;

  const DepotDividendSourceBar({super.key, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = context.watch<DepotDividendState>();
    final fetchedAt = state.fetchedAt;
    final hint = theme.textTheme.bodySmall?.copyWith(color: theme.hintColor);

    return Column(
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
            state.isFetching
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: l10n.depotDividendRefresh,
                    onPressed: onRefresh,
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
    );
  }
}
