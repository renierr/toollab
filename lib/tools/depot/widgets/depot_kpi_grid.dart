import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/metric_tile.dart';

import '../depot_format.dart';
import '../models/depot_summary.dart';

class DepotKpiGrid extends StatelessWidget {
  final DepotSummary summary;
  final DepotFormat format;
  final List<double?> valueTrend;

  const DepotKpiGrid({
    super.key,
    required this.summary,
    required this.format,
    required this.valueTrend,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final neutral = Theme.of(context).colorScheme.primary;
    Color gain(double v) => DepotFormat.gainColor(v) ?? neutral;
    final xirr = summary.xirr;
    final ttwror = summary.ttwror;

    return MetricGrid(
      children: [
        MetricTile(
          label: l10n.depotKpiValue,
          value: format.money(summary.valueEnd),
          icon: Icons.account_balance_wallet_outlined,
          color: AppTheme.accentGreen,
          compact: true,
          trend: valueTrend,
        ),
        MetricTile(
          label: l10n.depotKpiTotalGain,
          value: format.money(summary.totalGain, signed: true),
          icon: Icons.trending_up,
          color: gain(summary.totalGain),
          compact: true,
        ),
        MetricTile(
          label: l10n.depotKpiUnrealized,
          value: format.percent(summary.unrealizedReturn),
          icon: Icons.show_chart,
          color: gain(summary.unrealizedReturn),
          compact: true,
        ),
        if (xirr != null)
          MetricTile(
            label: l10n.depotKpiXirr,
            value: format.percent(xirr),
            icon: Icons.percent,
            color: gain(xirr),
            compact: true,
          ),
        if (ttwror != null)
          MetricTile(
            label: l10n.depotKpiTtwror,
            value: format.percent(ttwror),
            icon: Icons.timeline,
            color: gain(ttwror),
            compact: true,
          ),
        MetricTile(
          label: l10n.depotKpiRealized,
          value: format.money(summary.realizedGain, signed: true),
          icon: Icons.sell_outlined,
          color: gain(summary.realizedGain),
          compact: true,
        ),
        MetricTile(
          label: l10n.depotKpiDividends,
          value: format.money(summary.dividends),
          icon: Icons.payments_outlined,
          color: AppTheme.accentTeal,
          compact: true,
        ),
        MetricTile(
          label: l10n.depotKpiCosts,
          value: format.money(summary.fees + summary.taxes),
          icon: Icons.receipt_long_outlined,
          color: AppTheme.accentAmber,
          compact: true,
        ),
      ],
    );
  }
}
