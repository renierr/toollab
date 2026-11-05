import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';

import '../depot_format.dart';
import '../models/depot_capital_flow.dart';
import '../models/depot_monthly_returns.dart';
import '../models/depot_summary.dart';
import '../models/depot_transaction.dart';
import 'depot_legend_dot.dart';
import 'depot_mode_chips.dart';
import 'depot_return_heatmap.dart';

/// Value change per year, split into new money and market gain, with the
/// dividends paid out; a year expands into its months.
class DepotCapitalFlowCard extends StatefulWidget {
  final List<DepotChartPoint> points;
  final List<DepotTransaction> transactions;
  final DepotMonthlyReturns returns;
  final DepotFormat format;
  final bool inPercent;
  final ValueChanged<bool> onModeChanged;

  const DepotCapitalFlowCard({
    super.key,
    required this.points,
    required this.transactions,
    required this.returns,
    required this.format,
    required this.inPercent,
    required this.onModeChanged,
  });

  static const Color newMoneyColor = AppTheme.accentBlue;
  static const Color dividendColor = AppTheme.accentAmber;

  @override
  State<DepotCapitalFlowCard> createState() => _DepotCapitalFlowCardState();
}

class _DepotCapitalFlowCardState extends State<DepotCapitalFlowCard> {
  int? _expandedYear;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    if (widget.points.length < 2) return const SizedBox.shrink();
    final years = DepotCapitalFlow.years(widget.points, widget.transactions);
    final expanded = _expandedYear;
    final months = expanded == null
        ? const <DepotCapitalFlow>[]
        : DepotCapitalFlow.months(widget.points, widget.transactions, expanded);
    final yearScale = _Scale.of(years);
    final monthScale = _Scale.of(months);
    final monthName = DateFormat.MMM(
      Localizations.localeOf(context).toString(),
    );

    final hint = theme.textTheme.bodySmall?.copyWith(color: theme.hintColor);
    final latest = years.first;
    var invested = 0.0, market = 0.0, dividends = 0.0;
    for (final year in years) {
      invested += year.newMoney;
      market += year.marketGain;
      dividends += year.dividends;
    }
    final format = widget.format;

    return Card(
      child: ExpansionTile(
        key: const PageStorageKey('depot-growth'),
        title: Text(l10n.depotFlowTitle, style: theme.textTheme.titleSmall),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.depotFlowYearSummary(
                '${latest.year}',
                format.compactMoney(latest.newMoney),
                format.compactMoney(latest.marketGain),
                format.compactMoney(latest.dividends),
              ),
              style: hint,
            ),
            Text(
              l10n.depotFlowTotalSummary(
                format.compactMoney(invested),
                format.compactMoney(market),
                format.compactMoney(dividends),
              ),
              style: hint,
            ),
          ],
        ),
        shape: const Border(),
        collapsedShape: const Border(),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: DepotModeChips(
              selected: widget.inPercent,
              options: [
                (false, l10n.depotFlowModeAmount),
                (true, l10n.depotFlowModeReturn),
              ],
              onSelected: widget.onModeChanged,
            ),
          ),
          const SizedBox(height: 8),
          if (widget.inPercent)
            DepotReturnHeatmap(returns: widget.returns, format: format)
          else ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  DepotLegendDot(
                    color: DepotCapitalFlowCard.newMoneyColor,
                    label: l10n.depotFlowNewMoney,
                  ),
                  DepotLegendDot(
                    color: AppTheme.statusGreen,
                    label: l10n.depotFlowMarket,
                  ),
                  DepotLegendDot(
                    color: DepotCapitalFlowCard.dividendColor,
                    label: l10n.depotFlowDividends,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            for (final year in years) ...[
              _FlowRow(
                label: '${year.year}',
                flow: year,
                scale: yearScale,
                format: widget.format,
                expanded: expanded == year.year,
                onTap: () => setState(
                  () =>
                      _expandedYear = expanded == year.year ? null : year.year,
                ),
              ),
              if (expanded == year.year)
                for (final month in months)
                  Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: _FlowRow(
                      label: monthName.format(
                        DateTime(month.year, month.month!),
                      ),
                      flow: month,
                      scale: monthScale,
                      format: widget.format,
                    ),
                  ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Shared zero line of one list of bars.
class _Scale {
  final double negative;
  final double positive;

  const _Scale(this.negative, this.positive);

  factory _Scale.of(List<DepotCapitalFlow> flows) {
    var negative = 0.0, positive = 0.0;
    for (final flow in flows) {
      for (final v in [flow.newMoney, flow.marketGain, flow.dividends]) {
        negative = math.max(negative, -v);
        positive = math.max(positive, v);
      }
    }
    return _Scale(negative, positive);
  }

  double get span => negative + positive;
}

class _FlowRow extends StatelessWidget {
  final String label;
  final DepotCapitalFlow flow;
  final _Scale scale;
  final DepotFormat format;
  final bool? expanded;
  final VoidCallback? onTap;

  const _FlowRow({
    required this.label,
    required this.flow,
    required this.scale,
    required this.format,
    this.expanded,
    this.onTap,
  });

  String _signed(double value) =>
      '${value > 0 ? '+' : ''}${format.compactMoney(value)}';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final small = theme.textTheme.labelSmall;
    final marketColor = flow.marketGain < 0
        ? AppTheme.statusRed
        : AppTheme.statusGreen;
    final isExpanded = expanded;
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: isExpanded == true ? FontWeight.bold : null,
              ),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                _DivergingBar(
                  value: flow.newMoney,
                  scale: scale,
                  color: DepotCapitalFlowCard.newMoneyColor,
                ),
                const SizedBox(height: 3),
                _DivergingBar(
                  value: flow.marketGain,
                  scale: scale,
                  color: marketColor,
                ),
                const SizedBox(height: 3),
                _DivergingBar(
                  value: flow.dividends,
                  scale: scale,
                  color: DepotCapitalFlowCard.dividendColor,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 64,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_signed(flow.newMoney), style: small),
                Text(
                  _signed(flow.marketGain),
                  style: small?.copyWith(color: marketColor),
                ),
                Text(
                  _signed(flow.dividends),
                  style: small?.copyWith(
                    color: DepotCapitalFlowCard.dividendColor,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 24,
            child: isExpanded == null
                ? null
                : Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: theme.hintColor,
                  ),
          ),
        ],
      ),
    );
    return Tooltip(
      message: [
        label,
        '${l10n.depotFlowNewMoney}: ${format.money(flow.newMoney, signed: true)}',
        '${l10n.depotFlowMarket}: '
            '${format.money(flow.marketGain, signed: true)}',
        '${l10n.depotFlowDividends}: '
            '${format.money(flow.dividends, signed: true)}',
        '${l10n.depotFlowValueChange}: '
            '${format.money(flow.valueChange, signed: true)}',
      ].join('\n'),
      child: onTap == null ? row : InkWell(onTap: onTap, child: row),
    );
  }
}

class _DivergingBar extends StatelessWidget {
  final double value;
  final _Scale scale;
  final Color color;

  const _DivergingBar({
    required this.value,
    required this.scale,
    required this.color,
  });

  static const double _height = 8;

  @override
  Widget build(BuildContext context) {
    final axis = Theme.of(context).dividerColor;
    return SizedBox(
      height: _height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final span = scale.span;
          if (span <= 0) return const SizedBox.shrink();
          final width = constraints.maxWidth;
          final zero = width * scale.negative / span;
          final length = width * value.abs() / span;
          return Stack(
            children: [
              Positioned(
                left: value < 0 ? zero - length : zero,
                width: length,
                top: 0,
                bottom: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Positioned(
                left: zero,
                width: 1,
                top: -2,
                bottom: -2,
                child: ColoredBox(color: axis),
              ),
            ],
          );
        },
      ),
    );
  }
}
