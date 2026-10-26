import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../depot_colors.dart';
import '../depot_format.dart';
import '../depot_portfolio_labels.dart';
import '../models/depot_holding.dart';

class DepotHoldingTile extends StatelessWidget {
  final DepotHolding holding;

  /// Figures for the selected period; null when Parqet had none.
  final DepotHoldingPerformance? performance;
  final DepotFormat format;

  /// Share of the scope's open value, in percent.
  final double weight;

  const DepotHoldingTile({
    super.key,
    required this.holding,
    required this.performance,
    required this.format,
    required this.weight,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final color = DepotColors.assetType(holding.assetType);
    final name = holding.name.isEmpty
        ? DepotPortfolioLabels.assetType(l10n, holding.assetType)
        : holding.name;
    final subtitle = [
      ?holding.identifier,
      if (holding.shares != 0)
        l10n.depotHoldingShares(format.shares(holding.shares)),
      if (holding.isSold) l10n.depotHoldingSold,
      if (!holding.isSold && weight > 0) format.percent(weight, signed: false),
    ].join(' · ');
    final gain = performance?.gain;
    final returnPercent = performance?.returnPercent;
    final change = [
      if (gain != null) format.money(gain, signed: true),
      if (returnPercent != null) format.percent(returnPercent),
    ].join('  ');

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        child: Text(
          name.characters.first.toUpperCase(),
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            format.money(holding.currentValue),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          if (change.isNotEmpty)
            Text(
              change,
              style: theme.textTheme.bodySmall?.copyWith(
                color: DepotFormat.gainColor(returnPercent ?? gain ?? 0),
              ),
            ),
        ],
      ),
    );
  }
}
