import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';

import '../../depot_format.dart';
import '../../simulation/depot_sim_engine.dart';
import '../depot_legend_dot.dart';

/// Real depot value per age: the middle 80 and 50 percent of the runs, the
/// median and the path with the expected return every year.
class DepotSimFanChart extends StatefulWidget {
  final DepotSimResult result;
  final DepotSimOutcome outcome;
  final DepotFormat format;

  const DepotSimFanChart({
    super.key,
    required this.result,
    required this.outcome,
    required this.format,
  });

  static const Color bandColor = AppTheme.accentGreen;
  static const Color expectedColor = AppTheme.accentBlue;

  @override
  State<DepotSimFanChart> createState() => _DepotSimFanChartState();
}

class _DepotSimFanChartState extends State<DepotSimFanChart> {
  int? _selected;

  @override
  void didUpdateWidget(covariant DepotSimFanChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selected != null && _selected! >= widget.outcome.bands.length) {
      _selected = null;
    }
  }

  void _select(Offset position, double width) {
    final n = widget.outcome.bands.length;
    final index = (position.dx / width * (n - 1)).round().clamp(0, n - 1);
    if (index != _selected) setState(() => _selected = index);
  }

  void _clear() {
    if (_selected != null) setState(() => _selected = null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final bands = widget.outcome.bands;
    final selected = _selected;
    final band = selected == null ? null : bands[selected];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 220,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              return MouseRegion(
                onHover: (e) => _select(e.localPosition, width),
                onExit: (_) => _clear(),
                child: GestureDetector(
                  onTapDown: (d) => _select(d.localPosition, width),
                  onHorizontalDragUpdate: (d) =>
                      _select(d.localPosition, width),
                  onHorizontalDragEnd: (_) => _clear(),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _FanPainter(
                            bands: bands,
                            expected: widget.result.expected,
                            age: widget.result.age,
                            markers: [
                              widget.result.retireAge,
                              widget.result.pensionAge,
                            ],
                            gridColor: theme.dividerColor,
                            markerColor: theme.hintColor,
                            labelStyle: theme.textTheme.labelSmall!.copyWith(
                              color: theme.hintColor,
                            ),
                            format: widget.format,
                            selected: selected,
                          ),
                        ),
                      ),
                      if (band != null)
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
                                color:
                                    theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                l10n.depotSimChartTooltip(
                                  widget.result.age + selected!,
                                  widget.format.axisMoney(band.p10),
                                  widget.format.axisMoney(band.p50),
                                  widget.format.axisMoney(band.p90),
                                ),
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
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            DepotLegendDot(
              color: DepotSimFanChart.bandColor.withValues(alpha: 0.25),
              label: l10n.depotSimLegendOuter,
            ),
            DepotLegendDot(
              color: DepotSimFanChart.bandColor.withValues(alpha: 0.5),
              label: l10n.depotSimLegendInner,
            ),
            DepotLegendDot(
              color: DepotSimFanChart.bandColor,
              label: l10n.depotSimLegendMedian,
            ),
            DepotLegendDot(
              color: DepotSimFanChart.expectedColor,
              label: l10n.depotSimLegendExpected(
                widget.format.percent(
                  widget.result.expectedReturn * 100,
                  signed: false,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FanPainter extends CustomPainter {
  final List<DepotSimBand> bands;
  final List<double> expected;
  final int age;
  final List<int> markers;
  final Color gridColor;
  final Color markerColor;
  final TextStyle labelStyle;
  final DepotFormat format;
  final int? selected;

  _FanPainter({
    required this.bands,
    required this.expected,
    required this.age,
    required this.markers,
    required this.gridColor,
    required this.markerColor,
    required this.labelStyle,
    required this.format,
    required this.selected,
  });

  static const double _labelHeight = 16;

  @override
  void paint(Canvas canvas, Size size) {
    if (bands.length < 2) return;
    // The top tenth of runs compounds into the stratosphere; scaling to it
    // would squash everything else.
    var maxY = 1.0;
    for (var i = 0; i < bands.length; i++) {
      maxY = math.max(maxY, bands[i].p75);
      if (i < expected.length) maxY = math.max(maxY, expected[i]);
    }
    maxY *= 1.15;

    final chart = Rect.fromLTWH(0, 0, size.width, size.height - _labelHeight);
    double x(int i) => chart.left + chart.width * i / (bands.length - 1);
    double y(double v) => chart.bottom - v.clamp(0, maxY) / maxY * chart.height;

    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final gy = chart.top + chart.height * i / 3;
      canvas.drawLine(Offset(chart.left, gy), Offset(chart.right, gy), grid);
    }

    Path area(
      double Function(DepotSimBand) low,
      double Function(DepotSimBand) high,
    ) {
      final path = Path()..moveTo(x(0), y(high(bands[0])));
      for (var i = 1; i < bands.length; i++) {
        path.lineTo(x(i), y(high(bands[i])));
      }
      for (var i = bands.length - 1; i >= 0; i--) {
        path.lineTo(x(i), y(low(bands[i])));
      }
      return path..close();
    }

    Path line(double Function(int) value, int count) {
      final path = Path()..moveTo(x(0), y(value(0)));
      for (var i = 1; i < count; i++) {
        path.lineTo(x(i), y(value(i)));
      }
      return path;
    }

    const color = DepotSimFanChart.bandColor;
    canvas
      ..save()
      ..clipRect(chart)
      ..drawPath(
        area((b) => b.p10, (b) => b.p90),
        Paint()..color = color.withValues(alpha: 0.18),
      )
      ..drawPath(
        area((b) => b.p25, (b) => b.p75),
        Paint()..color = color.withValues(alpha: 0.35),
      )
      ..drawPath(
        line((i) => bands[i].p50, bands.length),
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round,
      )
      ..drawPath(
        line((i) => expected[i], math.min(expected.length, bands.length)),
        Paint()
          ..color = DepotSimFanChart.expectedColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );

    final markerPaint = Paint()
      ..color = markerColor
      ..strokeWidth = 1;
    for (final marker in markers) {
      final i = marker - age;
      if (i <= 0 || i >= bands.length) continue;
      final mx = x(i);
      for (var dy = chart.top; dy < chart.bottom; dy += 6) {
        canvas.drawLine(
          Offset(mx, dy),
          Offset(mx, math.min(dy + 3, chart.bottom)),
          markerPaint,
        );
      }
    }

    final selected = this.selected;
    if (selected != null) {
      final sx = x(selected);
      canvas
        ..drawLine(Offset(sx, chart.top), Offset(sx, chart.bottom), markerPaint)
        ..drawCircle(
          Offset(sx, y(bands[selected].p50)),
          4,
          Paint()..color = color,
        );
    }
    canvas.restore();

    _text(canvas, format.axisMoney(maxY), Offset(4, chart.top + 2));
    _text(
      canvas,
      format.axisMoney(maxY / 3),
      Offset(4, chart.top + chart.height * 2 / 3 + 2),
    );
    final step = bands.length > 40 ? 10 : 5;
    for (
      var a = (age / step).ceil() * step;
      a < age + bands.length;
      a += step
    ) {
      final i = a - age;
      if (i < 2 || i > bands.length - 3) continue;
      _text(canvas, '$a', Offset(x(i), chart.bottom + 2), center: true);
    }
    _text(canvas, '$age', Offset(chart.left, chart.bottom + 2));
    _text(
      canvas,
      '${age + bands.length - 1}',
      Offset(chart.right, chart.bottom + 2),
      alignRight: true,
    );
  }

  void _text(
    Canvas canvas,
    String text,
    Offset offset, {
    bool alignRight = false,
    bool center = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = alignRight
        ? -painter.width
        : center
        ? -painter.width / 2
        : 0.0;
    painter.paint(canvas, offset.translate(dx, 0));
  }

  @override
  bool shouldRepaint(covariant _FanPainter old) =>
      old.bands != bands ||
      old.expected != expected ||
      old.selected != selected ||
      old.gridColor != gridColor ||
      old.labelStyle != labelStyle;
}
