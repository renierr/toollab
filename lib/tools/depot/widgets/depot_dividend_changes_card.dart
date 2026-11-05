import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';

import '../depot_format.dart';
import '../dividends/depot_dividend_changes.dart';
import 'depot_info_row.dart';

/// Stocks that raised or cut their dividend per share this year.
class DepotDividendChangesCard extends StatelessWidget {
  final int year;
  final List<DepotDividendChange> changes;
  final DepotFormat format;

  const DepotDividendChangesCard({
    super.key,
    required this.year,
    required this.changes,
    required this.format,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final amount = NumberFormat(
      '#,##0.00##',
      Localizations.localeOf(context).toString(),
    );
    final hint = theme.textTheme.bodySmall?.copyWith(color: theme.hintColor);
    final body = theme.textTheme.bodyMedium;
    final raised = changes.where((c) => c.percent > 0).length;

    return Card(
      child: ExpansionTile(
        key: const PageStorageKey('depot-dividend-changes'),
        title: Text(
          l10n.depotDividendChangesTitle('$year'),
          style: theme.textTheme.titleSmall,
        ),
        subtitle: Text(
          l10n.depotDividendChangesSummary(raised, changes.length - raised),
          style: hint,
        ),
        shape: const Border(),
        collapsedShape: const Border(),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          for (final change in changes)
            DepotInfoRow(
              padding: const EdgeInsets.symmetric(vertical: 3),
              title: Text(
                change.holding.name,
                style: body,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${amount.format(change.before)} → '
                '${amount.format(change.now)} ${change.currency}',
                style: hint,
              ),
              trailing: Text(
                format.percent(change.percent),
                style: body?.copyWith(
                  color: change.percent > 0
                      ? AppTheme.statusGreen
                      : AppTheme.statusRed,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
