import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../depot_colors.dart';
import '../depot_dividend_state.dart';
import '../depot_format.dart';
import '../dividends/depot_dividend_calendar.dart';
import 'depot_dividend_entry_tile.dart';
import 'depot_dividend_stack_bar.dart';

/// Twelve month tiles of one year; the selected month lists its payments.
class DepotDividendCalendarCard extends StatelessWidget {
  final DepotDividendCalendar calendar;
  final DepotFormat format;

  const DepotDividendCalendarCard({
    super.key,
    required this.calendar,
    required this.format,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = context.watch<DepotDividendState>();
    final year = state.year;
    final selected = state.month;
    final months = calendar.months(year);
    final maxTotal = months.fold<double>(
      0,
      (m, t) => t.total > m ? t.total : m,
    );
    final years = calendar.years.keys;
    final firstYear = years.isEmpty ? year : years.first;
    final lastYear = years.isEmpty ? year : years.last;
    final entries = calendar.entriesIn(year, selected);
    final yearTotal = months.fold<double>(0, (s, t) => s + t.total);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.depotDividendCalendarTitle,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  tooltip: l10n.depotDividendPrevYear,
                  onPressed: year > firstYear
                      ? () => state.setYear(year - 1)
                      : null,
                ),
                Text('$year', style: theme.textTheme.titleSmall),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  tooltip: l10n.depotDividendNextYear,
                  onPressed: year < lastYear
                      ? () => state.setYear(year + 1)
                      : null,
                ),
              ],
            ),
            Text(
              l10n.depotDividendYearTotal(format.money(yearTotal)),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
              ),
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                // Month tiles need ~90 px to keep their amount readable.
                final columns = constraints.maxWidth < 360
                    ? 3
                    : constraints.maxWidth < 600
                    ? 4
                    : 6;
                final width =
                    (constraints.maxWidth - 6 * (columns - 1)) / columns;
                return Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (var m = 1; m <= 12; m++)
                      SizedBox(
                        width: width,
                        child: _MonthTile(
                          month: DateTime(year, m),
                          totals: months[m - 1],
                          maxTotal: maxTotal,
                          selected: m == selected,
                          current:
                              year == calendar.today.year &&
                              m == calendar.today.month,
                          format: format,
                          onTap: () => state.selectMonth(m),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            Text(
              DateFormat.yMMMM(
                Localizations.localeOf(context).toString(),
              ).format(DateTime(year, selected)),
              style: theme.textTheme.titleSmall,
            ),
            if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  l10n.depotDividendMonthEmpty,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
              )
            else
              for (final e in entries)
                DepotDividendEntryTile(entry: e, format: format),
          ],
        ),
      ),
    );
  }
}

class _MonthTile extends StatelessWidget {
  final DateTime month;
  final DepotDividendTotals totals;
  final double maxTotal;
  final bool selected;
  final bool current;
  final DepotFormat format;
  final VoidCallback onTap;

  const _MonthTile({
    required this.month,
    required this.totals,
    required this.maxTotal,
    required this.selected,
    required this.current,
    required this.format,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final label = DateFormat.MMM(
      Localizations.localeOf(context).toString(),
    ).format(month);
    final hasExpected = totals.expected > 0 || totals.missing > 0;

    return Material(
      color: selected
          ? scheme.primaryContainer
          : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: current ? BorderSide(color: scheme.primary) : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: current ? FontWeight.bold : null,
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  totals.total <= 0
                      ? '–'
                      : '${hasExpected && totals.booked == 0 ? '≈ ' : ''}'
                            '${format.compactMoney(totals.total)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: totals.total <= 0
                        ? theme.hintColor
                        : totals.booked > 0
                        ? DepotColors.dividendBooked
                        : totals.missing > 0
                        ? DepotColors.dividendMissing
                        : DepotColors.dividendExpected,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              DepotDividendStackBar(
                totals: totals,
                maxTotal: maxTotal,
                axis: Axis.horizontal,
                thickness: 4,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
