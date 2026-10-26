import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';

import '../depot_colors.dart';
import '../depot_format.dart';
import '../models/depot_income_month.dart';
import 'depot_income_plot.dart';
import 'depot_legend_dot.dart';

class DepotIncomeChart extends StatelessWidget {
  final List<DepotIncomeMonth> months;
  final DepotFormat format;

  const DepotIncomeChart({
    super.key,
    required this.months,
    required this.format,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final total = months.fold<double>(0, (sum, m) => sum + m.total);
    final hasInterest = months.any((m) => m.interest > 0);
    final average = months.isEmpty ? 0.0 : total / months.length;
    final median = DepotIncomeMonth.medianTotal(months);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.depotIncomeTitle, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  l10n.depotIncomeTotal(format.money(total)),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  l10n.depotIncomeAverage(format.money(average)),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  l10n.depotIncomeMedian(format.money(median)),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.accentAmber,
                  ),
                ),
              ],
            ),
            if (hasInterest) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  DepotLegendDot(
                    color: DepotColors.dividendBooked,
                    label: l10n.depotKpiDividends,
                  ),
                  DepotLegendDot(
                    color: AppTheme.accentPurple,
                    label: l10n.depotTxInterest,
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            if (total <= 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(l10n.depotNoDataYet),
              )
            else
              DepotIncomePlot(months: months, format: format, median: median),
          ],
        ),
      ),
    );
  }
}
