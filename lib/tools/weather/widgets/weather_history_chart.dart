import 'dart:async';
import 'dart:math' as math;

import 'package:intl/intl.dart' hide TextDirection;
import 'package:material_ui/material_ui.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/health_chart_tooltip.dart';

import '../models/weather_history_summary.dart';
import '../weather_colors.dart';
import '../weather_units.dart';

/// Daily or monthly buckets: temperature band (low to high) with the average
/// as a line, precipitation bars below.
class WeatherHistoryChart extends StatefulWidget {
  const WeatherHistoryChart({
    super.key,
    required this.summary,
    required this.units,
    this.height = 260,
  });

  final HistorySummary summary;
  final WeatherUnits units;
  final double height;

  @override
  State<WeatherHistoryChart> createState() => _WeatherHistoryChartState();
}

class _WeatherHistoryChartState extends State<WeatherHistoryChart>
    with DisposeCleanup {
  /// Touch has no "leave" event, so the readout hides itself.
  static const Duration _touchLinger = Duration(seconds: 3);
  static const Duration _mouseLinger = Duration(seconds: 6);

  int? _selected;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    onDispose(() => _hideTimer?.cancel());
  }

  @override
  void didUpdateWidget(WeatherHistoryChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.summary.range != widget.summary.range) _selected = null;
  }

  void _select(Offset local, double width, {required bool touch}) {
    final slots = _HistoryPainter.slots(widget.summary);
    if (slots.isEmpty) return;
    final plot = width - _HistoryPainter.left - _HistoryPainter.right;
    final slot = ((local.dx - _HistoryPainter.left) / plot * slots.length)
        .floor()
        .clamp(0, slots.length - 1);
    final index = widget.summary.buckets.indexWhere(
      (b) => b.start == slots[slot],
    );
    final next = index < 0 ? null : index;
    if (next != _selected) setState(() => _selected = next);
    _hideTimer?.cancel();
    _hideTimer = Timer(touch ? _touchLinger : _mouseLinger, _clear);
  }

  void _clear() {
    _hideTimer?.cancel();
    if (mounted && _selected != null) setState(() => _selected = null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final summary = widget.summary;
    final selected = _selected;
    final bucket = selected == null || selected >= summary.buckets.length
        ? null
        : summary.buckets[selected];
    return SizedBox(
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final x = bucket == null
              ? 0.0
              : _HistoryPainter.centerX(summary, bucket.start, width);
          return MouseRegion(
            onHover: (e) => _select(e.localPosition, width, touch: false),
            onExit: (_) => _clear(),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => _select(d.localPosition, width, touch: true),
              onHorizontalDragStart: (d) =>
                  _select(d.localPosition, width, touch: true),
              onHorizontalDragUpdate: (d) =>
                  _select(d.localPosition, width, touch: true),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _HistoryPainter(
                        summary: summary,
                        units: widget.units,
                        locale: locale,
                        selected: bucket?.start,
                        axisStyle: theme.textTheme.labelSmall!.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        gridColor: theme.dividerColor.withValues(alpha: .5),
                        cursorColor: theme.colorScheme.onSurface.withValues(
                          alpha: .12,
                        ),
                      ),
                    ),
                  ),
                  if (bucket != null)
                    Positioned(
                      top: 4,
                      left: x < width / 2 ? x + 14 : null,
                      right: x >= width / 2 ? width - x + 14 : null,
                      child: IgnorePointer(
                        child: _BucketReadout(
                          bucket: bucket,
                          monthly: summary.range.period == HistoryPeriod.year,
                          units: widget.units,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BucketReadout extends StatelessWidget {
  const _BucketReadout({
    required this.bucket,
    required this.monthly,
    required this.units,
  });

  final HistoryBucket bucket;
  final bool monthly;
  final WeatherUnits units;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final date = monthly
        ? DateFormat.yMMMM(locale).format(bucket.start)
        : DateFormat.MMMEd(locale).format(bucket.start);
    final low = bucket.minTemperature;
    final high = bucket.maxTemperature;
    return HealthChartTooltip(
      title: date,
      readings: [
        if (low != null && high != null)
          (
            color: WeatherColors.temperatureLine,
            text:
                '${l10n.weatherTemperature} ${units.temperatureText(low)} – ${units.temperatureText(high)}',
          ),
        if (bucket.meanTemperature != null)
          (
            color: WeatherColors.temperature(bucket.meanTemperature!),
            text:
                '${l10n.weatherHistoryAverage} ${units.temperatureText(bucket.meanTemperature)}',
          ),
        (
          color: WeatherColors.precipitationBar,
          text:
              '${l10n.weatherPrecipitation} ${units.precipitationText(bucket.precipitation)}',
        ),
        if (bucket.sunshineMinutes > 0)
          (
            color: WeatherColors.sun,
            text:
                '${l10n.weatherSunshine} ${l10n.weatherSunshineHours((bucket.sunshineMinutes / 60).toStringAsFixed(1))}',
          ),
        if (bucket.maxGust != null)
          (
            color: WeatherColors.windLine,
            text: l10n.weatherGusts(units.windText(bucket.maxGust)),
          ),
      ],
    );
  }
}

class _HistoryPainter extends CustomPainter {
  _HistoryPainter({
    required this.summary,
    required this.units,
    required this.locale,
    required this.selected,
    required this.axisStyle,
    required this.gridColor,
    required this.cursorColor,
  });

  final HistorySummary summary;
  final WeatherUnits units;
  final String locale;
  final DateTime? selected;
  final TextStyle axisStyle;
  final Color gridColor;
  final Color cursorColor;

  static const double left = 40;
  static const double right = 4;
  static const double _bottom = 20;

  /// Share of the height for the temperature part; the rest holds the bars.
  static const double _tempShare = .66;

  /// Every day (or month) of the period, recorded or not, so gaps show.
  static List<DateTime> slots(HistorySummary summary) {
    final range = summary.range;
    if (range.period == HistoryPeriod.year) {
      return [for (var m = 1; m <= 12; m++) DateTime(range.start.year, m)];
    }
    return [
      for (
        var d = range.start;
        d.isBefore(range.end);
        d = DateTime(d.year, d.month, d.day + 1)
      )
        d,
    ];
  }

  static double centerX(HistorySummary summary, DateTime start, double width) {
    final all = slots(summary);
    final i = all.indexOf(start);
    final slot = (width - left - right) / all.length;
    return left + slot * (i + .5);
  }

  String _label(DateTime t) => switch (summary.range.period) {
    HistoryPeriod.year => DateFormat.MMM(locale).format(t).substring(0, 1),
    HistoryPeriod.week => DateFormat.E(locale).format(t),
    _ => '${t.day}',
  };

  @override
  void paint(Canvas canvas, Size size) {
    final all = slots(summary);
    if (all.isEmpty) return;
    final byStart = {for (final b in summary.buckets) b.start: b};
    const plotLeft = left;
    final plotRight = size.width - right;
    final slot = (plotRight - plotLeft) / all.length;
    final chartBottom = size.height - _bottom;
    final tempBottom = 8 + (chartBottom - 8) * _tempShare - 10;
    final barTop = tempBottom + 16;

    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    // Temperature scale.
    final temps = [
      for (final b in summary.buckets) ...[
        ?b.minTemperature,
        ?b.maxTemperature,
      ],
    ].map(units.temperature).toList();
    if (temps.isNotEmpty) {
      var lo = temps.reduce(math.min);
      var hi = temps.reduce(math.max);
      final pad = math.max((hi - lo) * .1, 1.0);
      lo -= pad;
      hi += pad;
      double y(double celsius) =>
          tempBottom -
          (units.temperature(celsius) - lo) / (hi - lo) * (tempBottom - 8);
      for (var i = 0; i <= 3; i++) {
        final v = lo + (hi - lo) * i / 3;
        final dy = tempBottom - (v - lo) / (hi - lo) * (tempBottom - 8);
        canvas.drawLine(Offset(plotLeft, dy), Offset(plotRight, dy), grid);
        _text(canvas, '${v.round()}°', Offset(0, dy - 7), left - 6);
      }
      if (selected != null) {
        final i = all.indexOf(selected!);
        if (i >= 0) {
          canvas.drawRect(
            Rect.fromLTWH(plotLeft + slot * i, 4, slot, chartBottom - 4),
            Paint()..color = cursorColor,
          );
        }
      }
      final band = slot * .56;
      final mean = Path();
      var started = false;
      for (var i = 0; i < all.length; i++) {
        final b = byStart[all[i]];
        final cx = plotLeft + slot * (i + .5);
        if (b == null || b.minTemperature == null) {
          started = false;
          continue;
        }
        final top = y(b.maxTemperature!);
        final bottom = y(b.minTemperature!);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(
              cx - band / 2,
              top,
              cx + band / 2,
              math.max(bottom, top + 2),
            ),
            Radius.circular(math.min(band / 2, 4)),
          ),
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                WeatherColors.temperature(b.maxTemperature!),
                WeatherColors.temperature(b.minTemperature!),
              ],
            ).createShader(Rect.fromLTRB(cx - band, top, cx + band, bottom)),
        );
        final m = b.meanTemperature;
        if (m != null) {
          if (started) {
            mean.lineTo(cx, y(m));
          } else {
            mean.moveTo(cx, y(m));
            started = true;
          }
        }
      }
      canvas.drawPath(
        mean,
        Paint()
          ..color = WeatherColors.temperatureLine
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round,
      );
    }

    // Precipitation bars.
    final maxRain = math.max(
      1.0,
      summary.buckets.fold<double>(0, (a, b) => math.max(a, b.precipitation)),
    );
    canvas.drawLine(
      Offset(plotLeft, chartBottom),
      Offset(plotRight, chartBottom),
      grid,
    );
    _text(
      canvas,
      units.precipitationText(maxRain),
      Offset(0, barTop - 7),
      left - 6,
    );
    final barWidth = slot * .56;
    for (var i = 0; i < all.length; i++) {
      final b = byStart[all[i]];
      if (b == null || b.precipitation <= 0) continue;
      final h = b.precipitation / maxRain * (chartBottom - barTop);
      final cx = plotLeft + slot * (i + .5);
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTRB(
            cx - barWidth / 2,
            chartBottom - math.max(h, 1.5),
            cx + barWidth / 2,
            chartBottom,
          ),
          topLeft: const Radius.circular(2),
          topRight: const Radius.circular(2),
        ),
        Paint()..color = WeatherColors.precipitationBar,
      );
    }

    // X labels, thinned so they never collide.
    final every = math.max(1, (36 / slot).ceil());
    for (var i = 0; i < all.length; i += every) {
      final cx = plotLeft + slot * (i + .5);
      _text(
        canvas,
        _label(all[i]),
        Offset(cx - 20, chartBottom + 4),
        40,
        align: TextAlign.center,
      );
    }
  }

  void _text(
    Canvas canvas,
    String text,
    Offset at,
    double width, {
    TextAlign align = TextAlign.right,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: axisStyle),
      textAlign: align,
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(minWidth: width, maxWidth: width);
    painter.paint(canvas, at);
    painter.dispose();
  }

  @override
  bool shouldRepaint(_HistoryPainter old) =>
      old.summary != summary ||
      old.selected != selected ||
      old.units.settings != units.settings ||
      old.axisStyle != axisStyle;
}
