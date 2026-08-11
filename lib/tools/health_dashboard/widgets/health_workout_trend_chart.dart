import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:tool_lab/l10n/app_localizations.dart';

import '../health_value_format.dart';

enum HealthTrendChartStyle { bars, line }

class HealthWorkoutTrendChart extends StatefulWidget {
  final List<double?> values;
  final String unit;
  final Color color;
  final HealthTrendChartStyle style;
  final List<double?>? overlayValues;
  final String? overlayUnit;
  final Color? overlayColor;
  final DateTime? endDate;
  final ValueChanged<int>? onDayTap;
  final String? label;
  final String? overlayLabel;

  const HealthWorkoutTrendChart({
    super.key,
    required this.values,
    required this.unit,
    required this.color,
    this.style = HealthTrendChartStyle.bars,
    this.overlayValues,
    this.overlayUnit,
    this.overlayColor,
    this.endDate,
    this.onDayTap,
    this.label,
    this.overlayLabel,
  });

  @override
  State<HealthWorkoutTrendChart> createState() =>
      _HealthWorkoutTrendChartState();
}

class _HealthWorkoutTrendChartState extends State<HealthWorkoutTrendChart> {
  bool _showPrimary = true;
  bool _showOverlay = true;
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (widget.overlayValues != null)
        _Legend(
          primaryLabel: widget.label ?? widget.unit,
          primaryColor: widget.color,
          primaryVisible: _showPrimary,
          overlayLabel: widget.overlayLabel ?? widget.overlayUnit ?? '',
          overlayColor: widget.overlayColor ?? Colors.red,
          overlayVisible: _showOverlay,
          onPrimaryTap: () => setState(() => _showPrimary = !_showPrimary),
          onOverlayTap: () => setState(() => _showOverlay = !_showOverlay),
        ),
      SizedBox(
        height: 170,
        child: LayoutBuilder(
          builder: (context, constraints) => MouseRegion(
            onHover: (event) =>
                _updateSelection(event.localPosition, constraints.maxWidth),
            onExit: (_) => setState(() => _selectedIndex = null),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) =>
                  _updateSelection(details.localPosition, constraints.maxWidth),
              onHorizontalDragUpdate: (details) =>
                  _updateSelection(details.localPosition, constraints.maxWidth),
              onTapUp: (details) {
                final index = _indexAt(
                  details.localPosition,
                  constraints.maxWidth,
                );
                if (index != null) widget.onDayTap?.call(index);
                setState(() => _selectedIndex = null);
              },
              onHorizontalDragEnd: (_) => setState(() => _selectedIndex = null),
              onTapCancel: () => setState(() => _selectedIndex = null),
              child: Stack(
                children: [
                  CustomPaint(
                    key: ValueKey(widget.endDate),
                    size: Size.infinite,
                    painter: _HealthWorkoutTrendPainter(
                      values: widget.values,
                      unit: widget.unit,
                      lineColor: widget.color,
                      style: widget.style,
                      overlayValues: _showOverlay ? widget.overlayValues : null,
                      overlayUnit: widget.overlayUnit,
                      overlayColor: widget.overlayColor,
                      endDate: widget.endDate,
                      compact: constraints.maxWidth < 420,
                      showPrimary: _showPrimary,
                      selectedIndex: _selectedIndex,
                      locale: Localizations.localeOf(context).toString(),
                      gridColor: Theme.of(
                        context,
                      ).colorScheme.outline.withValues(alpha: 0.2),
                      labelColor: Theme.of(context).hintColor,
                    ),
                  ),
                  if (_selectedIndex != null)
                    Positioned(
                      left: _tooltipLeft(constraints.maxWidth),
                      top: 0,
                      child: _Tooltip(
                        index: _selectedIndex!,
                        values: widget.values,
                        unit: widget.unit,
                        color: widget.color,
                        overlayValues: _showOverlay
                            ? widget.overlayValues
                            : null,
                        overlayUnit: widget.overlayUnit,
                        overlayColor: widget.overlayColor,
                        endDate: widget.endDate,
                        locale: Localizations.localeOf(context).toString(),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  );

  void _updateSelection(Offset position, double width) {
    final index = _indexAt(position, width);
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);
  }

  int? _indexAt(Offset position, double width) {
    final rightPadding = _showOverlay && widget.overlayValues != null
        ? 76.0
        : 42.0;
    final plotWidth = width - 34 - rightPadding;
    if (position.dx < 34 || position.dx > 34 + plotWidth || position.dy > 132) {
      return null;
    }
    return (((position.dx - 34) / plotWidth) * widget.values.length)
        .clamp(0.0, widget.values.length - 1.0)
        .floor();
  }

  double _tooltipLeft(double width) {
    const tooltipWidth = 112.0;
    final rightPadding = _showOverlay && widget.overlayValues != null
        ? 76.0
        : 42.0;
    final plotWidth = width - 34 - rightPadding;
    final marker =
        34 + plotWidth * (_selectedIndex! + 0.5) / widget.values.length;
    return (marker - tooltipWidth / 2).clamp(0.0, width - tooltipWidth);
  }
}

class _HealthWorkoutTrendPainter extends CustomPainter {
  final List<double?> values;
  final String unit;
  final Color lineColor;
  final HealthTrendChartStyle style;
  final List<double?>? overlayValues;
  final String? overlayUnit;
  final Color? overlayColor;
  final DateTime? endDate;
  final String locale;
  final Color gridColor;
  final Color labelColor;
  final bool compact;
  final bool showPrimary;
  final int? selectedIndex;

  const _HealthWorkoutTrendPainter({
    required this.values,
    required this.unit,
    required this.lineColor,
    required this.style,
    this.overlayValues,
    this.overlayUnit,
    this.overlayColor,
    this.endDate,
    required this.locale,
    required this.gridColor,
    required this.labelColor,
    required this.compact,
    required this.showPrimary,
    this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final now = endDate ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final minimum = unit == 'km'
        ? 1.0
        : unit == 'bpm'
        ? 60.0
        : 1.0;
    final rawMaxValue = math.max(
      minimum,
      values.whereType<double>().fold(0.0, math.max),
    );
    final rawMinValue = values.whereType<double>().fold(rawMaxValue, math.min);
    final padding = math.max((rawMaxValue - rawMinValue).abs() * 0.15, 1.0);
    final minValue = style == HealthTrendChartStyle.line
        ? math.max(0, rawMinValue - padding)
        : 0.0;
    final maxValue = style == HealthTrendChartStyle.line
        ? rawMaxValue + padding
        : rawMaxValue;
    final plot = Rect.fromLTWH(
      34,
      14,
      size.width - (overlayValues == null ? 42 : 76),
      size.height - 52,
    );
    _label(canvas, unit, Offset(plot.left, 0));
    final barWidth = plot.width / values.length * 0.56;
    if (selectedIndex != null) {
      final x = plot.left + plot.width * (selectedIndex! + 0.5) / values.length;
      canvas.drawLine(
        Offset(x, plot.top),
        Offset(x, plot.bottom),
        Paint()
          ..color = labelColor
          ..strokeWidth = 1,
      );
    }
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var index = 0; index < 3; index++) {
      final y = plot.top + plot.height * index / 2;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);
      _label(
        canvas,
        _formatAxisValue(minValue + (maxValue - minValue) * (2 - index) / 2),
        Offset(plot.left - 5, y - 6),
        alignRight: true,
      );
    }
    final segments = <List<Offset>>[];
    var segment = <Offset>[];
    for (var index = 0; index < values.length; index++) {
      final value = values[index];
      final height =
          ((value ?? minValue) - minValue) /
          (maxValue - minValue) *
          plot.height;
      final x = plot.left + plot.width * (index + 0.5) / values.length;
      if (showPrimary && style == HealthTrendChartStyle.bars) {
        final bar = RRect.fromRectAndRadius(
          Rect.fromLTWH(
            x - barWidth / 2,
            plot.bottom - height,
            barWidth,
            height,
          ),
          const Radius.circular(5),
        );
        canvas.drawRRect(bar, Paint()..color = lineColor);
      } else if (showPrimary && value != null) {
        segment.add(Offset(x, plot.bottom - height));
      } else if (segment.isNotEmpty) {
        segments.add(segment);
        segment = <Offset>[];
      }
      if (showPrimary &&
          value != null &&
          value > 0 &&
          (!compact || index.isEven)) {
        _label(
          canvas,
          _formatValue(value),
          Offset(x, plot.bottom - height - 16),
          centered: true,
        );
      }
      _label(
        canvas,
        _dateLabel(today.subtract(Duration(days: 6 - index)), compact),
        Offset(x, plot.bottom + 4),
        centered: true,
      );
    }
    if (segment.isNotEmpty) segments.add(segment);
    if (style == HealthTrendChartStyle.line) {
      final paint = Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      for (final points in segments) {
        canvas.drawPath(_smoothPath(points), paint);
        for (final point in points) {
          canvas.drawCircle(point, 4, Paint()..color = lineColor);
        }
      }
    }
    _drawOverlay(canvas, plot);
  }

  void _drawOverlay(Canvas canvas, Rect plot) {
    final values = overlayValues;
    if (values == null || values.whereType<double>().isEmpty) return;
    final min = values.whereType<double>().reduce((a, b) => a < b ? a : b);
    final maximum = values.whereType<double>().reduce((a, b) => a > b ? a : b);
    final padding = math.max((maximum - min).abs() * 0.15, 1.0).toDouble();
    final lower = min - padding;
    final upper = maximum + padding;
    _label(canvas, overlayUnit ?? '', Offset(plot.right, 0), alignRight: true);
    _label(
      canvas,
      _formatOverlayAxis(upper),
      Offset(plot.right + 5, plot.top - 6),
    );
    _label(
      canvas,
      _formatOverlayAxis(lower),
      Offset(plot.right + 5, plot.bottom - 6),
    );
    final segments = <List<Offset>>[];
    var segment = <Offset>[];
    for (var index = 0; index < values.length; index++) {
      final value = values[index];
      if (value == null) {
        if (segment.isNotEmpty) segments.add(segment);
        segment = <Offset>[];
        continue;
      }
      final x = plot.left + plot.width * (index + 0.5) / values.length;
      final y = plot.bottom - (value - lower) / (upper - lower) * plot.height;
      segment.add(Offset(x, y));
      if (!compact || index.isOdd) {
        _label(
          canvas,
          _formatOverlay(value),
          Offset(x, y - 16),
          centered: true,
        );
      }
    }
    if (segment.isNotEmpty) segments.add(segment);
    final paint = Paint()
      ..color = overlayColor ?? Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (final points in segments) {
      canvas.drawPath(_smoothPath(points), paint);
      for (final point in points) {
        canvas.drawCircle(
          point,
          4,
          Paint()..color = overlayColor ?? Colors.red,
        );
      }
    }
  }

  Path _smoothPath(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var index = 1; index < points.length; index++) {
      final previous = points[index - 1];
      final point = points[index];
      final controlX = (previous.dx + point.dx) / 2;
      path.cubicTo(
        controlX,
        previous.dy,
        controlX,
        point.dy,
        point.dx,
        point.dy,
      );
    }
    return path;
  }

  String _dateLabel(DateTime date, bool compact) => compact
      ? '${DateFormat.E(locale).format(date)} ${date.day}'
      : '${DateFormat.E(locale).format(date)}\n${date.day} ${DateFormat.MMM(locale).format(date)}';

  String _formatValue(double value) =>
      unit == 'min' ? _duration(value.round()) : healthValue(value, unit);

  String _formatAxisValue(double value) => healthAxisNumber(value, unit);

  String _duration(int minutes) =>
      '${minutes ~/ 60}h ${minutes.remainder(60)}m';

  String _formatOverlay(double value) => healthValue(value, overlayUnit ?? '');

  String _formatOverlayAxis(double value) =>
      healthAxisNumber(value, overlayUnit ?? '');

  void _label(
    Canvas canvas,
    String text,
    Offset anchor, {
    bool centered = false,
    bool alignRight = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: labelColor, fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final x = alignRight
        ? anchor.dx - painter.width
        : centered
        ? anchor.dx - painter.width / 2
        : anchor.dx;
    painter.paint(canvas, Offset(x, anchor.dy));
  }

  @override
  bool shouldRepaint(_HealthWorkoutTrendPainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.unit != unit ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.style != style ||
      oldDelegate.overlayValues != overlayValues ||
      oldDelegate.overlayUnit != overlayUnit ||
      oldDelegate.overlayColor != overlayColor ||
      oldDelegate.endDate != endDate ||
      oldDelegate.locale != locale ||
      oldDelegate.gridColor != gridColor ||
      oldDelegate.labelColor != labelColor ||
      oldDelegate.selectedIndex != selectedIndex;
}

class _Legend extends StatelessWidget {
  final String primaryLabel, overlayLabel;
  final Color primaryColor, overlayColor;
  final bool primaryVisible, overlayVisible;
  final VoidCallback onPrimaryTap, onOverlayTap;
  const _Legend({
    required this.primaryLabel,
    required this.primaryColor,
    required this.primaryVisible,
    required this.overlayLabel,
    required this.overlayColor,
    required this.overlayVisible,
    required this.onPrimaryTap,
    required this.onOverlayTap,
  });
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 12,
    children: [
      _LegendItem(
        label: primaryLabel,
        color: primaryColor,
        selected: primaryVisible,
        onTap: onPrimaryTap,
      ),
      _LegendItem(
        label: overlayLabel,
        color: overlayColor,
        selected: overlayVisible,
        onTap: onOverlayTap,
      ),
    ],
  );
}

class _LegendItem extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _LegendItem({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Opacity(
      opacity: selected ? 1 : .45,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    ),
  );
}

class _Tooltip extends StatelessWidget {
  final int index;
  final List<double?> values;
  final String unit;
  final Color color;
  final List<double?>? overlayValues;
  final String? overlayUnit;
  final Color? overlayColor;
  final DateTime? endDate;
  final String locale;
  const _Tooltip({
    required this.index,
    required this.values,
    required this.unit,
    required this.color,
    this.overlayValues,
    this.overlayUnit,
    this.overlayColor,
    this.endDate,
    required this.locale,
  });
  String _value(BuildContext context, double? value, String unit) {
    if (value == null) {
      return AppLocalizations.of(context).healthDashboardChartNoData;
    }
    if (unit == 'min') {
      final minutes = value.round();
      return '${minutes ~/ 60}h ${minutes.remainder(60)}m';
    }
    return healthValue(value, unit);
  }

  @override
  Widget build(BuildContext context) {
    final date = (endDate ?? DateTime.now()).subtract(
      Duration(days: 6 - index),
    );
    return Align(
      alignment: Alignment.topCenter,
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat.yMMMd(locale).format(date),
                style: Theme.of(context).textTheme.labelMedium,
              ),
              _row(context, color, _value(context, values[index], unit)),
              if (overlayValues != null)
                _row(
                  context,
                  overlayColor ?? Colors.red,
                  _value(context, overlayValues![index], overlayUnit ?? ''),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, Color color, String value) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 5),
      Text(value),
    ],
  );
}
