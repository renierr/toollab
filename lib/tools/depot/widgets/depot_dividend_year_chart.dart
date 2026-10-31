import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../depot_colors.dart';
import '../depot_format.dart';
import '../dividends/depot_dividend_calendar.dart';
import '../models/depot_dividend_history.dart';
import 'depot_dividend_history_view.dart';
import 'depot_dividend_stack_bar.dart';
import 'depot_legend_dot.dart';

class DepotDividendYearChart extends StatelessWidget {
  final DepotDividendCalendar calendar;
  final DepotFormat format;
  final DepotDividendHistory? history;

  const DepotDividendYearChart({
    super.key,
    required this.calendar,
    required this.format,
    this.history,
  });

  static const _maxYears = 12;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    var years = calendar.years.entries.toList();
    if (years.length > _maxYears) {
      years = years.sublist(years.length - _maxYears);
    }
    if (years.isEmpty) return const SizedBox.shrink();
    final maxTotal = years.fold<double>(
      0,
      (m, e) => e.value.total > m ? e.value.total : m,
    );
    final hint = theme.textTheme.labelSmall?.copyWith(color: theme.hintColor);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.depotDividendYearsTitle,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                DepotLegendDot(
                  color: DepotColors.dividendBooked,
                  label: l10n.depotDividendStatusBooked,
                ),
                DepotLegendDot(
                  color: DepotColors.dividendMissing,
                  label: l10n.depotDividendStatusMissing,
                ),
                DepotLegendDot(
                  color: DepotColors.dividendExpected,
                  label: l10n.depotDividendExpectedLegend,
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 160,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final MapEntry(key: year, value: totals) in years)
                    Expanded(
                      child: Tooltip(
                        message: [
                          '$year',
                          '${l10n.depotDividendStatusBooked}: '
                              '${format.money(totals.booked)}',
                          if (totals.missing > 0)
                            '${l10n.depotDividendStatusMissing}: '
                                '${format.money(totals.missing)}',
                          if (totals.expected > 0)
                            '${l10n.depotDividendExpectedLegend}: '
                                '${format.money(totals.expected)}',
                        ].join('\n'),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Column(
                            children: [
                              FittedBox(
                                child: Text(
                                  totals.total <= 0
                                      ? ''
                                      : format.compactMoney(totals.total),
                                  style: hint,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Expanded(
                                child: Center(
                                  child: DepotDividendStackBar(
                                    totals: totals,
                                    maxTotal: maxTotal,
                                    axis: Axis.vertical,
                                    thickness: 18,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              FittedBox(
                                child: Text(
                                  '$year',
                                  style: hint?.copyWith(
                                    fontWeight: year == calendar.today.year
                                        ? FontWeight.bold
                                        : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (history != null)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(l10n.depotDividendHistoryTitle),
                children: [DepotDividendHistoryView(history: history!)],
              ),
          ],
        ),
      ),
    );
  }
}
