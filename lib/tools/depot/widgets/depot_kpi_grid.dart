import 'package:material_ui/material_ui.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/metric_tile.dart';

import '../depot_format.dart';
import '../models/depot_summary.dart';

class DepotKpiGrid extends StatelessWidget {
  final DepotSummary summary;
  final DepotFormat format;
  final List<double?> valueTrend;
  final double? netInvested;
  final double costBasis;

  const DepotKpiGrid({
    super.key,
    required this.summary,
    required this.format,
    required this.valueTrend,
    required this.netInvested,
    required this.costBasis,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final neutral = Theme.of(context).colorScheme.primary;
    Color gain(double v) => DepotFormat.gainColor(v) ?? neutral;
    // Parqet reports exactly 0 for periods too short for an IRR.
    final xirr = summary.xirr == 0 ? null : summary.xirr;
    final ttwror = summary.ttwror;

    return MetricGrid(
      children: [
        MetricTile(
          label: l10n.depotKpiValue,
          value: format.money(summary.valueEnd),
          icon: Icons.account_balance_wallet_outlined,
          color: AppTheme.accentGreen,
          compact: true,
          info: l10n.depotKpiValueInfo,
          trend: valueTrend,
        ),
        if (netInvested case final netInvested?)
          MetricTile(
            label: l10n.depotKpiNetInvested,
            value: format.money(netInvested),
            icon: Icons.savings_outlined,
            color: AppTheme.accentBlue,
            compact: true,
            detail: l10n.depotKpiCostBasis(format.money(costBasis)),
            info: l10n.depotKpiInvestedInfo,
          ),
        MetricTile(
          label: l10n.depotKpiTotalGain,
          value: format.money(summary.totalGain, signed: true),
          icon: Icons.trending_up,
          color: gain(summary.totalGain),
          compact: true,
          detail: switch (netInvested) {
            final netInvested? when netInvested > 0 =>
              l10n.depotKpiOnNetInvested(
                format.percent(summary.totalGain / netInvested * 100),
              ),
            _ => null,
          },
          info: l10n.depotKpiTotalGainInfo,
        ),
        MetricTile(
          label: l10n.depotKpiUnrealized,
          value: format.percent(summary.unrealizedReturn),
          icon: Icons.show_chart,
          color: gain(summary.unrealizedReturn),
          compact: true,
          detail: format.money(summary.unrealizedGain, signed: true),
          info: l10n.depotKpiUnrealizedInfo,
        ),
        if (xirr ?? ttwror case final rate?)
          MetricTile(
            label: xirr != null ? l10n.depotKpiXirr : l10n.depotKpiTtwror,
            value: format.percent(rate),
            icon: Icons.percent,
            color: gain(rate),
            compact: true,
            detail: xirr != null && ttwror != null
                ? l10n.depotKpiTtwrorDetail(format.percent(ttwror))
                : null,
            info: l10n.depotKpiReturnInfo,
          ),
        MetricTile(
          label: l10n.depotKpiRealized,
          value: format.money(summary.realizedGain, signed: true),
          icon: Icons.sell_outlined,
          color: gain(summary.realizedGain),
          compact: true,
          info: l10n.depotKpiRealizedInfo,
        ),
        MetricTile(
          label: l10n.depotKpiDividends,
          value: format.money(summary.dividends),
          icon: Icons.payments_outlined,
          color: AppTheme.accentTeal,
          compact: true,
          info: l10n.depotKpiDividendsInfo,
        ),
        MetricTile(
          label: l10n.depotKpiCosts,
          value: format.money(summary.fees + summary.taxes),
          icon: Icons.receipt_long_outlined,
          color: AppTheme.accentAmber,
          compact: true,
          info: l10n.depotKpiCostsInfo,
        ),
      ],
    );
  }
}
