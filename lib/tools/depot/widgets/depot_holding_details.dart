import 'package:flutter/material.dart';
import 'package:tool_lab/helpers/format_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/data_row.dart';

import '../depot_format.dart';
import '../depot_portfolio_labels.dart';
import '../models/depot_holding.dart';
import '../models/depot_period.dart';

/// Every figure of one holding, shown when its row is expanded.
class DepotHoldingDetails extends StatelessWidget {
  final DepotHolding holding;
  final DepotHoldingPerformance? performance;
  final DepotPeriod period;
  final DepotFormat format;
  final double weight;

  const DepotHoldingDetails({
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
    final h = holding;
    final periodLabel = DepotPortfolioLabels.period(l10n, period);
    final gain = performance?.gain;
    final returnPercent = performance?.returnPercent;
    final xirr = h.xirr;
    final quoteAt = h.quoteAt;
    final earliest = h.earliestActivity;

    final rows = <(String, String)>[
      (l10n.depotDetailType, DepotPortfolioLabels.kind(l10n, h.kind)),
      if (h.isin != null) (l10n.depotDetailIsin, h.isin!),
      if (h.isin == null && h.symbol != null)
        (l10n.depotDetailSymbol, h.symbol!),
      if (h.shares != 0) (l10n.depotDetailShares, format.shares(h.shares)),
      if (h.purchasePrice != 0)
        (l10n.depotDetailPurchasePrice, format.money(h.purchasePrice)),
      if (h.currentPrice != 0)
        (l10n.depotDetailCurrentPrice, format.money(h.currentPrice)),
      if (quoteAt != null)
        (l10n.depotDetailQuoteAt, FormatHelper.dateTime(quoteAt)),
      (l10n.depotDetailPurchaseValue, format.money(h.purchaseValue)),
      (l10n.depotDetailCurrentValue, format.money(h.currentValue)),
      if (weight > 0)
        (l10n.depotDetailWeight, format.percent(weight, signed: false)),
      if (gain != null)
        (
          l10n.depotDetailPeriodGain(periodLabel),
          format.money(gain, signed: true),
        ),
      if (returnPercent != null)
        (
          l10n.depotDetailPeriodReturn(periodLabel),
          format.percent(returnPercent),
        ),
      (
        l10n.depotDetailUnrealized,
        '${format.money(h.unrealizedGain, signed: true)} '
            '(${format.percent(h.unrealizedReturn)})',
      ),
      (l10n.depotDetailRealized, format.money(h.realizedGain, signed: true)),
      (l10n.depotDetailDividends, format.money(h.dividends)),
      (l10n.depotKpiCosts, format.money(h.fees + h.taxes)),
      if (xirr != null) (l10n.depotKpiXirr, format.percent(xirr)),
      if (earliest != null)
        (
          l10n.depotDetailFirstActivity,
          FormatHelper.dateTime(earliest, style: DateStyle.dateOnly),
        ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Two label/value columns only once each still has room to read.
        final columns = constraints.maxWidth >= 520 ? 2 : 1;
        final width = (constraints.maxWidth - 24 * (columns - 1)) / columns;
        return Wrap(
          spacing: 24,
          runSpacing: 6,
          children: [
            for (final (label, value) in rows)
              SizedBox(
                width: width,
                child: InfoRow(label: label, value: value),
              ),
          ],
        );
      },
    );
  }
}
