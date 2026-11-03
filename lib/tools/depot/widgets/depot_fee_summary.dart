import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/metric_tile.dart';

import '../depot_format.dart';
import '../models/depot_fee_report.dart';
import '../models/depot_transaction.dart';
import 'depot_info_row.dart';

/// Fee breakdown of one year: totals, fee rate, brokers and priciest trades.
class DepotFeeSummary extends StatelessWidget {
  final List<DepotTransaction> transactions;
  final int year;

  const DepotFeeSummary({
    super.key,
    required this.transactions,
    required this.year,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final reports = DepotFeeReport.forYear(transactions, year);
    if (reports.isEmpty) return const SizedBox.shrink();
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(l10n.depotFeesTitle),
      children: [
        for (final report in reports)
          _FeeCurrency(report: report, showCurrency: reports.length > 1),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _FeeCurrency extends StatelessWidget {
  final DepotFeeReport report;
  final bool showCurrency;

  const _FeeCurrency({required this.report, required this.showCurrency});

  /// Fee rate above which a trade is highlighted as expensive.
  static const double _expensiveRate = 1;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final format = DepotFormat.of(context, report.currency);
    final neutral = theme.colorScheme.primary;
    final average = report.averagePerTrade;
    final rate = report.ratePercent;
    final previous = report.previousTotal;
    final named = report.brokers.where((b) => b.broker != null).length;
    final splitBrokers = report.brokers.length > 1 && named > 0;
    final rows = <(String, double)>[
      if (report.buys > 0) (l10n.depotFeesBuys(report.buys), report.buyFees),
      if (report.sells > 0)
        (l10n.depotFeesSells(report.sells), report.sellFees),
      if (report.others > 0)
        (l10n.depotFeesOther(report.others), report.otherFees),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showCurrency)
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: Text(report.currency, style: theme.textTheme.titleSmall),
          ),
        MetricGrid(
          children: [
            MetricTile(
              label: l10n.depotFeesTotal,
              value: format.money(report.total),
              icon: Icons.receipt_long_outlined,
              color: AppTheme.accentAmber,
              compact: true,
            ),
            MetricTile(
              label: l10n.depotFeesTrades,
              value: '${report.trades}',
              unit: report.freeTrades > 0
                  ? l10n.depotFeesFree(report.freeTrades)
                  : null,
              icon: Icons.swap_horiz,
              color: neutral,
              compact: true,
            ),
            MetricTile(
              label: l10n.depotFeesAverage,
              value: average == null ? '–' : format.money(average),
              icon: Icons.calculate_outlined,
              color: neutral,
              compact: true,
            ),
            MetricTile(
              label: l10n.depotFeesRate,
              value: rate == null ? '–' : format.percent(rate, signed: false),
              icon: Icons.percent,
              color: neutral,
              compact: true,
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final (label, amount) in rows)
          DepotInfoRow(
            padding: const EdgeInsets.symmetric(vertical: 3),
            title: Text(label, style: theme.textTheme.bodyMedium),
            trailing: Text(
              format.money(amount),
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        if (splitBrokers) ...[
          _GroupTitle(l10n.depotFeesByBroker),
          for (final broker in report.brokers)
            DepotInfoRow(
              padding: const EdgeInsets.symmetric(vertical: 4),
              title: Text(
                broker.broker ?? l10n.depotFeesUnknownBroker,
                style: theme.textTheme.bodyMedium,
              ),
              subtitle: broker.volume > 0
                  ? _Hint(
                      format.percent(
                        broker.fees / broker.volume * 100,
                        signed: false,
                      ),
                    )
                  : null,
              trailing: Text(
                format.money(broker.fees),
                textAlign: TextAlign.end,
                style: theme.textTheme.bodyMedium,
              ),
            ),
        ],
        if (report.priciest.isNotEmpty) ...[
          _GroupTitle(l10n.depotFeesPriciest),
          for (final entry in report.priciest)
            _PriciestTrade(
              entry: entry,
              format: format,
              expensive: entry.rate > _expensiveRate,
            ),
        ],
        if (previous != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _Hint(
              l10n.depotFeesPreviousYear(
                format.money(previous),
                format.money(report.total - previous, signed: true),
              ),
            ),
          ),
      ],
    );
  }
}

class _PriciestTrade extends StatelessWidget {
  final DepotFeeTrade entry;
  final DepotFormat format;
  final bool expensive;

  const _PriciestTrade({
    required this.entry,
    required this.format,
    required this.expensive,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final trade = entry.trade;
    final type = trade.type == DepotTransactionType.buy
        ? l10n.depotTxBuy
        : l10n.depotTxSell;
    final date = MaterialLocalizations.of(
      context,
    ).formatShortDate(trade.datetime);
    return DepotInfoRow(
      padding: const EdgeInsets.symmetric(vertical: 6),
      title: Text(
        trade.holdingName.isEmpty ? type : trade.holdingName,
        style: theme.textTheme.bodyMedium,
      ),
      subtitle: _Hint('$date · $type · ${format.money(entry.volume)}'),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            format.money(trade.fee.abs()),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            format.percent(entry.rate, signed: false),
            style: theme.textTheme.bodySmall?.copyWith(
              color: expensive
                  ? AppTheme.statusRed
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupTitle extends StatelessWidget {
  final String text;

  const _GroupTitle(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 4),
    child: Text(text, style: Theme.of(context).textTheme.labelLarge),
  );
}

class _Hint extends StatelessWidget {
  final String text;

  const _Hint(this.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
