import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/metric_tile.dart';

import '../depot_format.dart';
import '../depot_fund_costs.dart';
import 'depot_holding_avatar.dart';
import 'depot_info_row.dart';

/// Weighted TER of the open funds and what it costs per year.
class DepotFundCostCard extends StatefulWidget {
  final DepotFundCosts costs;
  final DepotFormat format;

  const DepotFundCostCard({
    super.key,
    required this.costs,
    required this.format,
  });

  static const int topCount = 5;

  /// TER fractions above which a fund counts as pricey and as expensive.
  static const double priceyRatio = 0.005;
  static const double expensiveRatio = 0.01;

  static Color? ratioColor(double ratio) => ratio > expensiveRatio
      ? AppTheme.statusRed
      : ratio > priceyRatio
      ? AppTheme.statusAmber
      : null;

  @override
  State<DepotFundCostCard> createState() => _DepotFundCostCardState();
}

class _DepotFundCostCardState extends State<DepotFundCostCard> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final costs = widget.costs;
    final format = widget.format;
    if (!costs.hasCosts) return const SizedBox.shrink();
    final known = [
      for (final fund in costs.funds)
        if (fund.expenseRatio != null) fund,
    ];
    final shown = _showAll
        ? known
        : known.take(DepotFundCostCard.topCount).toList();
    final missing = costs.missing;
    final fundRatio = costs.fundRatio;
    final depotRatio = costs.depotRatio;
    final maxCost = costs.maxCost;
    final neutral = theme.colorScheme.primary;
    String ratio(double? value) =>
        value == null ? '–' : format.percent(value * 100, signed: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.depotFundCostTitle, style: theme.textTheme.titleSmall),
        const SizedBox(height: 12),
        MetricGrid(
          wideColumns: 3,
          children: [
            MetricTile(
              label: l10n.depotFundCostFundRatio,
              value: ratio(fundRatio),
              icon: Icons.percent,
              color: fundRatio == null
                  ? neutral
                  : DepotFundCostCard.ratioColor(fundRatio) ?? neutral,
              compact: true,
            ),
            MetricTile(
              label: l10n.depotFundCostDepotRatio,
              value: ratio(depotRatio),
              icon: Icons.account_balance_wallet_outlined,
              color: neutral,
              compact: true,
            ),
            MetricTile(
              label: l10n.depotFundCostYearly,
              value: format.money(costs.yearlyCost),
              icon: Icons.receipt_long_outlined,
              color: AppTheme.accentAmber,
              compact: true,
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final fund in shown)
          _FundCostRow(
            key: ValueKey(fund.key),
            fund: fund,
            barFraction: maxCost > 0 ? fund.yearlyCost! / maxCost : 0,
            format: format,
          ),
        if (known.length > DepotFundCostCard.topCount)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() => _showAll = !_showAll),
              child: Text(
                _showAll
                    ? l10n.depotXRayShowLess
                    : l10n.depotXRayShowAll(known.length),
              ),
            ),
          ),
        if (missing.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              l10n.depotFundCostMissing(
                missing.length,
                missing.map((fund) => fund.holding.name).join(', '),
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
              ),
            ),
          ),
      ],
    );
  }
}

class _FundCostRow extends StatelessWidget {
  final DepotFundCost fund;
  final double barFraction;
  final DepotFormat format;

  const _FundCostRow({
    super.key,
    required this.fund,
    required this.barFraction,
    required this.format,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final holding = fund.holding;
    final ratio = fund.expenseRatio!;
    final ratioColor = DepotFundCostCard.ratioColor(ratio);
    final hint = theme.textTheme.bodySmall?.copyWith(color: theme.hintColor);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          DepotInfoRow(
            leading: DepotHoldingAvatar(
              name: holding.name,
              colorSeed: holding.identifier ?? holding.id,
              size: 28,
            ),
            title: Text(
              holding.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
            subtitle: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: format.percent(ratio * 100, signed: false),
                    style: ratioColor == null
                        ? null
                        : TextStyle(
                            color: ratioColor,
                            fontWeight: FontWeight.w600,
                          ),
                  ),
                  TextSpan(text: ' · ${format.money(fund.value)}'),
                ],
              ),
              style: hint,
            ),
            trailing: Text(
              format.money(fund.yearlyCost!),
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: barFraction.clamp(0, 1),
              minHeight: 4,
              color: ratioColor ?? theme.colorScheme.primary,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
  }
}
