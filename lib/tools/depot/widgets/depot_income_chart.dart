import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';

import '../depot_format.dart';

class DepotIncomeChart extends StatelessWidget {
  final List<({DateTime month, double amount})> months;
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
    final total = months.fold<double>(0, (sum, m) => sum + m.amount);
    final maxAmount = months.fold<double>(0, (m, e) => math.max(m, e.amount));
    final monthFormat = DateFormat.MMM(
      Localizations.localeOf(context).toString(),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Text(l10n.depotIncomeTitle, style: theme.textTheme.titleSmall),
                Text(
                  l10n.depotIncomeTotal(format.money(total)),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.accentTeal,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 120,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final m in months)
                    Expanded(
                      child: Tooltip(
                        message: format.money(m.amount),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Flexible(
                                child: FractionallySizedBox(
                                  alignment: Alignment.bottomCenter,
                                  heightFactor: maxAmount <= 0
                                      ? 0
                                      : (m.amount / maxAmount).clamp(0, 1),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: AppTheme.accentTeal,
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(3),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              FittedBox(
                                child: Text(
                                  monthFormat.format(m.month),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.hintColor,
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
