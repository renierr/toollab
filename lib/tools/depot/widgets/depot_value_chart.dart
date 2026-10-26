import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:tool_lab/helpers/format_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';

import '../depot_format.dart';
import '../depot_portfolio_state.dart';
import '../models/depot_summary.dart';

/// An intraday chart needs the time; a longer one only the date.
DateStyle _dateStyle(List<DepotChartPoint> points) =>
    points.last.date.difference(points.first.date) < const Duration(days: 2)
    ? DateStyle.dateAndTime
    : DateStyle.dateOnly;

class DepotValueChart extends StatelessWidget {
  final List<DepotChartPoint> points;
  final DepotRangeChange? change;
  final DepotFormat format;

  const DepotValueChart({
    super.key,
    required this.points,
    required this.change,
    required this.format,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final change = this.change;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.depotChartTitle, style: theme.textTheme.titleSmall),
            if (change != null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  _ChangeLabel(
                    label: l10n.depotChartChange,
                    value: format.money(change.valueChange, signed: true),
                    color: DepotFormat.gainColor(change.valueChange),
                  ),
                  _ChangeLabel(
                    label: l10n.depotChartGain,
                    value: format.money(change.gain, signed: true),
                    color: DepotFormat.gainColor(change.gain),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: points.length < 2
                  ? Center(
                      child: Text(
                        l10n.depotNoDataYet,
                        style: theme.textTheme.bodySmall,
                      ),
                    )
                  : _InteractiveChart(points: points, format: format),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              children: [
                _LegendDot(
                  color: AppTheme.accentGreen,
                  label: l10n.depotChartValue,
                ),
                _LegendDot(
                  color: theme.hintColor,
                  label: l10n.depotChartInvested,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChangeLabel extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _ChangeLabel({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label  ',
            style: TextStyle(color: theme.hintColor),
          ),
          TextSpan(
            text: value,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
      style: theme.textTheme.bodyMedium,
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 4),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class _InteractiveChart extends StatefulWidget {
  final List<DepotChartPoint> points;
  final DepotFormat format;

  const _InteractiveChart({required this.points, required this.format});

  @override
  State<_InteractiveChart> createState() => _InteractiveChartState();
}

class _InteractiveChartState extends State<_InteractiveChart> {
  int? _selected;

  @override
  void didUpdateWidget(covariant _InteractiveChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.points != widget.points) _selected = null;
  }

  void _select(Offset position, double width) {
    final n = widget.points.length;
    final index = (position.dx / width * (n - 1)).round().clamp(0, n - 1);
    if (index != _selected) setState(() => _selected = index);
  }

  void _clear() {
    if (_selected != null) setState(() => _selected = null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = _selected;
    final point = selected == null ? null : widget.points[selected];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return MouseRegion(
          onHover: (e) => _select(e.localPosition, width),
          onExit: (_) => _clear(),
          child: GestureDetector(
            onTapDown: (d) => _select(d.localPosition, width),
            onHorizontalDragUpdate: (d) => _select(d.localPosition, width),
            onHorizontalDragEnd: (_) => _clear(),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _ChartPainter(
                      points: widget.points,
                      valueColor: AppTheme.accentGreen,
                      capitalColor: theme.hintColor,
                      gridColor: theme.dividerColor,
                      labelStyle: theme.textTheme.labelSmall!.copyWith(
                        color: theme.hintColor,
                      ),
                      format: widget.format,
                      selected: selected,
                    ),
                  ),
                ),
                if (point != null)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${FormatHelper.dateTime(point.date, style: _dateStyle(widget.points))}  '
                          '${widget.format.money(point.value)} / '
                          '${widget.format.money(point.capital)}',
                          style: theme.textTheme.labelSmall,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ChartPainter extends CustomPainter {
  final List<DepotChartPoint> points;
  final Color valueColor;
  final Color capitalColor;
  final Color gridColor;
  final TextStyle labelStyle;
  final DepotFormat format;
  final int? selected;

  _ChartPainter({
    required this.points,
    required this.valueColor,
    required this.capitalColor,
    required this.gridColor,
    required this.labelStyle,
    required this.format,
    required this.selected,
  });

  static const double _labelHeight = 16;

  @override
  void paint(Canvas canvas, Size size) {
    var minY = double.infinity;
    var maxY = -double.infinity;
    for (final p in points) {
      minY = math.min(minY, math.min(p.value, p.capital));
      maxY = math.max(maxY, math.max(p.value, p.capital));
    }
    if (maxY - minY < 1) maxY = minY + 1;
    final pad = (maxY - minY) * 0.08;
    minY -= pad;
    maxY += pad;

    final chart = Rect.fromLTWH(0, 0, size.width, size.height - _labelHeight);
    Offset at(int i, double v) => Offset(
      chart.left + chart.width * i / (points.length - 1),
      chart.bottom - (v - minY) / (maxY - minY) * chart.height,
    );

    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= 2; i++) {
      final y = chart.top + chart.height * i / 2;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), grid);
    }

    final capital = Path();
    final value = Path();
    for (var i = 0; i < points.length; i++) {
      final c = at(i, points[i].capital);
      final v = at(i, points[i].value);
      if (i == 0) {
        capital.moveTo(c.dx, c.dy);
        value.moveTo(v.dx, v.dy);
      } else {
        capital.lineTo(c.dx, c.dy);
        value.lineTo(v.dx, v.dy);
      }
    }

    final fill = Path.from(value)
      ..lineTo(chart.right, chart.bottom)
      ..lineTo(chart.left, chart.bottom)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            valueColor.withValues(alpha: 0.3),
            valueColor.withValues(alpha: 0),
          ],
        ).createShader(chart),
    );
    canvas.drawPath(
      capital,
      Paint()
        ..color = capitalColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    canvas.drawPath(
      value,
      Paint()
        ..color = valueColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );

    final selected = this.selected;
    if (selected != null) {
      final x = at(selected, 0).dx;
      canvas.drawLine(
        Offset(x, chart.top),
        Offset(x, chart.bottom),
        Paint()
          ..color = capitalColor
          ..strokeWidth = 1,
      );
      canvas.drawCircle(
        at(selected, points[selected].value),
        4,
        Paint()..color = valueColor,
      );
    }

    _text(canvas, format.compactMoney(maxY - pad), Offset(4, chart.top + 2));
    _text(
      canvas,
      format.compactMoney(minY + pad),
      Offset(4, chart.bottom - 14),
    );
    final dateStyle = _dateStyle(points);
    _text(
      canvas,
      FormatHelper.dateTime(points.first.date, style: dateStyle),
      Offset(chart.left, chart.bottom + 2),
    );
    _text(
      canvas,
      FormatHelper.dateTime(points.last.date, style: dateStyle),
      Offset(chart.right, chart.bottom + 2),
      alignRight: true,
    );
  }

  void _text(
    Canvas canvas,
    String text,
    Offset offset, {
    bool alignRight = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      alignRight ? offset.translate(-painter.width, 0) : offset,
    );
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) =>
      old.points != points ||
      old.selected != selected ||
      old.valueColor != valueColor ||
      old.capitalColor != capitalColor ||
      old.gridColor != gridColor ||
      old.labelStyle != labelStyle;
}
