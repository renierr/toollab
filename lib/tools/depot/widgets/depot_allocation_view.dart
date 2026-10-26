import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../depot_colors.dart';
import '../depot_format.dart';
import '../depot_portfolio_labels.dart';
import '../models/depot_holding.dart';

/// Share of the portfolio value per asset kind.
class DepotAllocationView extends StatelessWidget {
  final Map<DepotHoldingKind, double> allocation;
  final DepotFormat format;

  const DepotAllocationView({
    super.key,
    required this.allocation,
    required this.format,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final total = allocation.values.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.depotAllocationTitle, style: theme.textTheme.titleSmall),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 14,
            child: Row(
              children: [
                for (final entry in allocation.entries)
                  Expanded(
                    flex: (entry.value / total * 1000).round().clamp(1, 1000),
                    child: ColoredBox(color: DepotColors.kind(entry.key)),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (final entry in allocation.entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: DepotColors.kind(entry.key),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    DepotPortfolioLabels.kinds(l10n, entry.key),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  format.percent(entry.value / total * 100, signed: false),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
                const SizedBox(width: 12),
                Text(format.money(entry.value)),
              ],
            ),
          ),
      ],
    );
  }
}
