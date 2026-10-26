import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../depot_colors.dart';
import '../depot_format.dart';
import '../dividends/depot_dividend_calendar.dart';
import 'depot_dividend_entry_tile.dart';

/// Payments the data source reports but Parqet has no booking for.
class DepotDividendMissingCard extends StatelessWidget {
  final List<DepotDividendEntry> entries;
  final DepotFormat format;

  const DepotDividendMissingCard({
    super.key,
    required this.entries,
    required this.format,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    if (entries.isEmpty) return const SizedBox.shrink();

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: DepotColors.dividendMissing.withValues(alpha: 0.6),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.report_outlined,
                    size: 20,
                    color: DepotColors.dividendMissing,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.depotDividendMissingTitle,
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
              child: Text(
                l10n.depotDividendMissingHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor,
                ),
              ),
            ),
            for (final e in entries.reversed)
              DepotDividendEntryTile(entry: e, format: format),
          ],
        ),
      ),
    );
  }
}
