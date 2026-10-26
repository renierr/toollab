import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../depot_colors.dart';
import '../depot_format.dart';
import '../depot_portfolio_labels.dart';
import '../models/depot_holding.dart';
import '../models/depot_period.dart';
import 'depot_holding_details.dart';

class DepotHoldingTile extends StatelessWidget {
  final DepotHolding holding;

  /// Figures for the selected period; null when Parqet had none.
  final DepotHoldingPerformance? performance;
  final DepotPeriod period;
  final DepotFormat format;

  /// Share of the scope's open value, in percent.
  final double weight;

  const DepotHoldingTile({
    super.key,
    required this.holding,
    required this.performance,
    required this.period,
    required this.format,
    required this.weight,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final kind = holding.kind;
    final name = holding.name.isEmpty
        ? DepotPortfolioLabels.kind(l10n, kind)
        : holding.name;
    final gain = performance?.gain;
    final returnPercent = performance?.returnPercent;
    final kindColor = DepotColors.kind(kind);

    return ExpansionTile(
      // Keeps the expanded state while the row scrolls out and back in.
      key: PageStorageKey('depot-holding-${holding.portfolioId}/${holding.id}'),
      tilePadding: const EdgeInsets.symmetric(horizontal: 8),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      shape: const Border(),
      collapsedShape: const Border(),
      dense: true,
      leading: _HoldingAvatar(
        name: name,
        color: DepotColors.holding(holding.identifier ?? holding.id),
      ),
      title: Text(
        name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: holding.isSold
                  ? l10n.depotHoldingSold
                  : DepotPortfolioLabels.kind(l10n, kind),
              style: TextStyle(color: kindColor, fontWeight: FontWeight.w600),
            ),
            if (gain != null)
              TextSpan(
                text: '  ${format.money(gain, signed: true)}',
                style: TextStyle(color: DepotFormat.gainColor(gain)),
              ),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall,
      ),
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
          if (returnPercent != null)
            Text(
              format.percent(returnPercent),
              style: theme.textTheme.bodySmall?.copyWith(
                color: DepotFormat.gainColor(returnPercent),
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
      children: [
        DepotHoldingDetails(
          holding: holding,
          performance: performance,
          period: period,
          format: format,
          weight: weight,
        ),
      ],
    );
  }
}

class _HoldingAvatar extends StatelessWidget {
  final String name;
  final Color color;

  const _HoldingAvatar({required this.name, required this.color});

  static String _initials(String name) {
    final words = name
        .split(RegExp(r'[\s\-&.,/]+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    final first = words.first.characters.first;
    if (words.length == 1) return first.toUpperCase();
    return (first + words[1].characters.first).toUpperCase();
  }

  @override
  Widget build(BuildContext context) => Container(
    width: 32,
    height: 32,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.6)),
    ),
    child: Text(
      _initials(name),
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
    ),
  );
}
