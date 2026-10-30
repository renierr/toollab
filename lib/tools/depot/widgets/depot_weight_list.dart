import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../depot_colors.dart';
import '../depot_format.dart';
import '../models/depot_fund_constituent.dart';
import '../models/depot_holding.dart';
import 'depot_weight_donut.dart';
import 'depot_weight_row.dart';

/// Every open position's share of the portfolio, largest first.
class DepotWeightList extends StatelessWidget {
  final List<DepotHolding> holdings;
  final DepotFormat format;
  final DepotHoldingKind Function(DepotHolding holding) kindOf;
  final List<DepotFundConstituent> Function(DepotHolding holding)
  constituentsOf;

  const DepotWeightList({
    super.key,
    required this.holdings,
    required this.format,
    required this.kindOf,
    required this.constituentsOf,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final open = [
      for (final holding in holdings)
        if (!holding.isSold && holding.currentValue > 0) holding,
    ]..sort((a, b) => b.currentValue.compareTo(a.currentValue));
    if (open.isEmpty) return const SizedBox.shrink();
    final total = open.fold<double>(0, (sum, h) => sum + h.currentValue);
    final largest = open.first.currentValue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.depotAllocationPositions,
                style: theme.textTheme.titleSmall,
              ),
            ),
            Text(
              format.money(total),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        DepotWeightDonut(holdings: open, format: format),
        const SizedBox(height: 12),
        for (final (index, holding) in open.indexed)
          DepotWeightRow(
            key: ValueKey('${holding.portfolioId}/${holding.id}'),
            holding: holding,
            kind: kindOf(holding),
            share: total <= 0 ? 0 : holding.currentValue / total,
            barFraction: largest <= 0 ? 0 : holding.currentValue / largest,
            barColor: DepotColors.weight(index, open.length),
            constituents: constituentsOf(holding),
            format: format,
          ),
      ],
    );
  }
}
