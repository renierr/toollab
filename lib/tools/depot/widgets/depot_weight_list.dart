import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../depot_colors.dart';
import '../depot_format.dart';
import '../depot_portfolio_labels.dart';
import '../models/depot_holding.dart';
import 'depot_holding_avatar.dart';

/// Every open position's share of the portfolio, largest first.
class DepotWeightList extends StatelessWidget {
  final List<DepotHolding> holdings;
  final DepotFormat format;

  const DepotWeightList({
    super.key,
    required this.holdings,
    required this.format,
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
        const SizedBox(height: 4),
        for (final holding in open)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                Row(
                  children: [
                    DepotHoldingAvatar(
                      name: holding.name,
                      colorSeed: holding.identifier ?? holding.id,
                      size: 28,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            holding.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium,
                          ),
                          Text(
                            DepotPortfolioLabels.kind(l10n, holding.kind),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.hintColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          format.percent(
                            total <= 0 ? 0 : holding.currentValue / total * 100,
                            signed: false,
                          ),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          format.money(holding.currentValue),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.hintColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                LayoutBuilder(
                  builder: (context, constraints) => Container(
                    height: 4,
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: SizedBox(
                      width:
                          constraints.maxWidth *
                          (largest <= 0 ? 0 : holding.currentValue / largest),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: DepotColors.holding(
                            holding.identifier ?? holding.id,
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
