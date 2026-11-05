import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/helpers/format_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';

import '../depot_benchmark_state.dart';
import '../depot_format.dart';
import '../depot_portfolio_state.dart';
import 'depot_legend_dot.dart';
import 'depot_mode_chips.dart';
import 'depot_value_chart.dart';

class DepotBenchmarkChart extends StatelessWidget {
  final DepotFormat format;

  const DepotBenchmarkChart({super.key, required this.format});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final number = NumberFormat.decimalPatternDigits(
      locale: Localizations.localeOf(context).toString(),
      decimalDigits: 2,
    );
    final state = context.watch<DepotBenchmarkState>();
    final portfolio = context.watch<DepotPortfolioState>();
    final needsLoad = state.needsLoad(portfolio.chart, portfolio.currency);
    if (needsLoad) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          final current = context.read<DepotPortfolioState>();
          if (current.chart.length >= 2) {
            state.load(
              current.chart,
              current.currency,
              income: DepotBenchmarkState.incomeOf(current.transactions),
            );
          }
        }
      });
    }
    final points = state.points;
    final comparing =
        state.selection != DepotBenchmark.off &&
        !needsLoad &&
        !state.loading &&
        !state.currencyMismatch &&
        !state.failed &&
        points.length >= 2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.depotBenchmarkTitle, style: theme.textTheme.titleSmall),
        DropdownButton<DepotBenchmark>(
          isExpanded: true,
          value: state.selection,
          onChanged: (value) {
            if (value != null) state.select(value);
          },
          items: [
            for (final b in DepotBenchmark.values)
              DropdownMenuItem(
                value: b,
                child: Text(
                  b == DepotBenchmark.off ? l10n.depotBenchmarkNone : b.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
        if (state.selection != DepotBenchmark.off)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: DepotModeChips(
              selected: state.inMoney,
              options: [
                (false, l10n.depotBenchmarkModeIndex),
                (true, l10n.depotBenchmarkModeMoney),
              ],
              onSelected: state.setInMoney,
            ),
          ),
        if (!comparing)
          DepotValueChart(
            points: portfolio.chart,
            format: format,
            interactive: state.selection == DepotBenchmark.off,
          ),
        if (state.selection != DepotBenchmark.off) ...[
          if (state.loading || needsLoad)
            const Center(child: CircularProgressIndicator())
          else if (state.currencyMismatch)
            Text(l10n.depotBenchmarkCurrency)
          else if (state.failed)
            TextButton(
              onPressed: () => state.load(
                portfolio.chart,
                portfolio.currency,
                force: true,
                income: DepotBenchmarkState.incomeOf(portfolio.transactions),
              ),
              child: Text(l10n.depotBenchmarkFailed),
            )
          else if (points.length < 2)
            Text(l10n.depotBenchmarkUnavailable)
          else if (comparing) ...[
            SizedBox(
              height: 200,
              width: double.infinity,
              child: CustomPaint(
                painter: _BenchmarkPainter(
                  points,
                  state.inMoney,
                  AppTheme.accentGreen,
                  theme.colorScheme.primary,
                  theme.dividerColor,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${FormatHelper.dateTime(points.first.date, style: DateStyle.dateOnly)} – '
              '${FormatHelper.dateTime(points.last.date, style: DateStyle.dateOnly)}',
            ),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                DepotLegendDot(
                  color: AppTheme.accentGreen,
                  label: state.inMoney
                      ? '${l10n.depotBenchmarkDepot}: ${format.money(points.last.value)}'
                      : '${l10n.depotBenchmarkPortfolio}: ${number.format(points.last.portfolio)}',
                ),
                DepotLegendDot(
                  color: theme.colorScheme.primary,
                  label: state.inMoney
                      ? '${state.selection.label}: ${format.money(points.last.shadow)}'
                      : '${state.selection.label}: ${number.format(points.last.benchmark)}',
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              state.inMoney
                  ? l10n.depotBenchmarkMoneyDifference(
                      format.money(
                        points.last.value - points.last.shadow,
                        signed: true,
                      ),
                    )
                  : l10n.depotBenchmarkDifference(
                      number.format(
                        points.last.portfolio - points.last.benchmark,
                      ),
                    ),
            ),
            if (state.inMoney)
              Text(
                l10n.depotBenchmarkMoneyHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor,
                ),
              ),
          ],
        ],
      ],
    );
  }
}

class _BenchmarkPainter extends CustomPainter {
  final List<DepotBenchmarkPoint> points;
  final bool inMoney;
  final Color portfolio;
  final Color benchmark;
  final Color grid;
  _BenchmarkPainter(
    this.points,
    this.inMoney,
    this.portfolio,
    this.benchmark,
    this.grid,
  );

  double _first(DepotBenchmarkPoint p) => inMoney ? p.value : p.portfolio;
  double _second(DepotBenchmarkPoint p) => inMoney ? p.shadow : p.benchmark;

  @override
  void paint(Canvas canvas, Size size) {
    var low = double.infinity;
    var high = -double.infinity;
    for (final p in points) {
      low = math.min(low, math.min(_first(p), _second(p)));
      high = math.max(high, math.max(_first(p), _second(p)));
    }
    if (high - low < 1) high = low + 1;
    final pad = (high - low) * 0.1;
    low -= pad;
    high += pad;
    final first = points.first.date.millisecondsSinceEpoch;
    final span = math.max(1, points.last.date.millisecondsSinceEpoch - first);
    Offset at(DepotBenchmarkPoint p, double value) => Offset(
      (p.date.millisecondsSinceEpoch - first) / span * size.width,
      size.height - (value - low) / (high - low) * size.height,
    );
    for (var i = 0; i < 3; i++) {
      final y = size.height * i / 2;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        Paint()..color = grid,
      );
    }
    void line(double Function(DepotBenchmarkPoint) value, Color color) {
      final path = Path();
      for (var i = 0; i < points.length; i++) {
        final p = at(points[i], value(points[i]));
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    line(_first, portfolio);
    line(_second, benchmark);
  }

  @override
  bool shouldRepaint(covariant _BenchmarkPainter old) =>
      old.points != points ||
      old.inMoney != inMoney ||
      old.portfolio != portfolio ||
      old.benchmark != benchmark ||
      old.grid != grid;
}
