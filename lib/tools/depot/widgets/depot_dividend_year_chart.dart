import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../depot_colors.dart';
import '../depot_format.dart';
import '../dividends/depot_dividend_calendar.dart';
import 'depot_dividend_stack_bar.dart';

class DepotDividendYearChart extends StatelessWidget {
  final DepotDividendCalendar calendar;
  final DepotFormat format;

  const DepotDividendYearChart({
    super.key,
    required this.calendar,
    required this.format,
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
                _Legend(
                  color: DepotColors.dividendBooked,
                  label: l10n.depotDividendStatusBooked,
                ),
                _Legend(
                  color: DepotColors.dividendMissing,
                  label: l10n.depotDividendStatusMissing,
                ),
                _Legend(
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
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;

  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}
