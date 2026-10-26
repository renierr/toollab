import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';

import '../depot_colors.dart';
import '../depot_format.dart';
import '../models/depot_income_month.dart';

const _plotHeight = 180.0;
const _labelSpace = 26.0;
const _ticks = [1.0, 0.75, 0.5, 0.25, 0.0];

double _axisMax(double value) {
  if (value <= 0) return 1;
  final magnitude = math.pow(10, (math.log(value) / math.ln10).floor());
  return (value / magnitude * 2).ceil() * magnitude / 2;
}

class DepotIncomePlot extends StatefulWidget {
  final List<DepotIncomeMonth> months;
  final DepotFormat format;
  final double median;

  const DepotIncomePlot({
    super.key,
    required this.months,
    required this.format,
    required this.median,
  });

  @override
  State<DepotIncomePlot> createState() => _DepotIncomePlotState();
}

class _DepotIncomePlotState extends State<DepotIncomePlot> with DisposeCleanup {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    onDispose(_scrollController.dispose);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textScale = MediaQuery.textScalerOf(context).scale(12) / 12;
    final maxTotal = widget.months.fold<double>(
      0,
      (value, month) => math.max(value, month.total),
    );
    final maximum = _axisMax(maxTotal);
    final labelStyle = theme.textTheme.bodySmall!.copyWith(
      fontSize: 11,
      color: theme.colorScheme.onSurfaceVariant,
    );
    final axisLabels = [
      for (final tick in _ticks) widget.format.axisMoney(maximum * tick),
    ];
    final axisWidth =
        axisLabels.fold<double>(0, (width, label) {
          final painter = TextPainter(
            text: TextSpan(text: label, style: labelStyle),
            textScaler: MediaQuery.textScalerOf(context),
            textDirection: Directionality.of(context),
          )..layout();
          final result = math.max(width, painter.width);
          painter.dispose();
          return result;
        }) +
        12;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: axisWidth,
          height: _plotHeight + _labelSpace * textScale,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (var i = 0; i < _ticks.length; i++)
                Positioned(
                  top:
                      _labelSpace * textScale +
                      _plotHeight * (1 - _ticks[i]) -
                      labelStyle.fontSize! * textScale / 2,
                  right: 10,
                  child: Text(axisLabels[i], style: labelStyle),
                ),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final minWidth = widget.months.length * 82.0 * textScale;
              final scrolls = constraints.maxWidth < minWidth;
              return Scrollbar(
                controller: _scrollController,
                thumbVisibility: scrolls,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: math.max(constraints.maxWidth, minWidth),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            height: _plotHeight + _labelSpace * textScale,
                            child: Stack(
                              children: [
                                for (final tick in _ticks)
                                  Positioned(
                                    top:
                                        _labelSpace * textScale +
                                        _plotHeight * (1 - tick),
                                    left: 0,
                                    right: 0,
                                    child: Divider(
                                      height: 1,
                                      thickness: 1,
                                      color: theme.colorScheme.outlineVariant,
                                    ),
                                  ),
                                Positioned.fill(
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      for (final month in widget.months)
                                        Expanded(
                                          child: _IncomeBar(
                                            month: month,
                                            maximum: maximum,
                                            format: widget.format,
                                            labelStyle: labelStyle,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  top:
                                      _labelSpace * textScale +
                                      _plotHeight *
                                          (1 - widget.median / maximum).clamp(
                                            0,
                                            1,
                                          ) -
                                      1.5,
                                  height: 3,
                                  child: IgnorePointer(
                                    child: Semantics(
                                      label: AppLocalizations.of(context)
                                          .depotIncomeMedian(
                                            widget.format.money(widget.median),
                                          ),
                                      child: const CustomPaint(
                                        key: ValueKey('income-median-line'),
                                        painter: _MedianLinePainter(
                                          color: AppTheme.accentAmber,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              for (final month in widget.months)
                                Expanded(
                                  child: Text(
                                    DateFormat.MMM(
                                      Localizations.localeOf(
                                        context,
                                      ).toString(),
                                    ).format(month.month),
                                    textAlign: TextAlign.center,
                                    style: labelStyle,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MedianLinePainter extends CustomPainter {
  final Color color;

  const _MedianLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (var x = 1.5; x < size.width; x += 6) {
      canvas.drawCircle(Offset(x, size.height / 2), 1.2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MedianLinePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _IncomeBar extends StatelessWidget {
  final DepotIncomeMonth month;
  final double maximum;
  final DepotFormat format;
  final TextStyle labelStyle;

  const _IncomeBar({
    required this.month,
    required this.maximum,
    required this.format,
    required this.labelStyle,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dividends = math.max(0.0, month.dividends);
    final interest = math.max(0.0, month.interest);
    final positiveTotal = dividends + interest;
    final height = _plotHeight * (month.total / maximum).clamp(0, 1);
    return Tooltip(
      message: [
        DateFormat.yMMMM(
          Localizations.localeOf(context).toString(),
        ).format(month.month),
        '${l10n.depotKpiDividends}: ${format.money(month.dividends)}',
        '${l10n.depotTxInterest}: ${format.money(month.interest)}',
      ].join('\n'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              format.money(month.total),
              style: labelStyle.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 5),
            SizedBox(
              height: height,
              width: 36,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (interest > 0)
                      Expanded(
                        flex: (interest / positiveTotal * 10000).round().clamp(
                          1,
                          10000,
                        ),
                        child: const ColoredBox(color: AppTheme.accentPurple),
                      ),
                    if (dividends > 0)
                      Expanded(
                        flex: (dividends / positiveTotal * 10000).round().clamp(
                          1,
                          10000,
                        ),
                        child: const ColoredBox(
                          color: DepotColors.dividendBooked,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
