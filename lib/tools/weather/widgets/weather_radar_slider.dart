import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../api/dwd_radar.dart';

class WeatherRadarSlider extends StatefulWidget {
  const WeatherRadarSlider({
    super.key,
    required this.times,
    required this.index,
    required this.nowIndex,
    required this.loaded,
    required this.rain,
    required this.hourLabel,
    required this.onChanged,
  });

  final List<DateTime> times;
  final int index;
  final int nowIndex;
  final bool Function(int index) loaded;
  final List<double?> rain;
  final String Function(DateTime time) hourLabel;
  final ValueChanged<int> onChanged;

  @override
  State<WeatherRadarSlider> createState() => _WeatherRadarSliderState();
}

class _WeatherRadarSliderState extends State<WeatherRadarSlider> {
  static const double _inset = 14;

  void _seek(Offset local, double width) {
    final count = widget.times.length;
    if (count < 2) return;
    final t = ((local.dx - _inset) / (width - 2 * _inset)).clamp(0.0, 1.0);
    final i = (t * (count - 1)).round();
    if (i == widget.index) return;
    if (widget.times[i].toLocal().minute == 0) HapticFeedback.selectionClick();
    widget.onChanged(i);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => _seek(d.localPosition, width),
          onHorizontalDragStart: (d) => _seek(d.localPosition, width),
          onHorizontalDragUpdate: (d) => _seek(d.localPosition, width),
          child: CustomPaint(
            size: Size(width, 74),
            painter: _SliderPainter(
              times: widget.times,
              index: widget.index,
              nowIndex: widget.nowIndex,
              loaded: [
                for (var i = 0; i < widget.times.length; i++) widget.loaded(i),
              ],
              rain: widget.rain,
              hourLabel: widget.hourLabel,
              inset: _inset,
              primary: theme.colorScheme.primary,
              future: theme.colorScheme.tertiary,
              track: theme.colorScheme.surfaceContainerHighest,
              tick: theme.colorScheme.outline,
              labelStyle: theme.textTheme.labelSmall!.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              thumbBorder: theme.colorScheme.surface,
            ),
          ),
        );
      },
    );
  }
}

class _SliderPainter extends CustomPainter {
  _SliderPainter({
    required this.times,
    required this.index,
    required this.nowIndex,
    required this.loaded,
    required this.rain,
    required this.hourLabel,
    required this.inset,
    required this.primary,
    required this.future,
    required this.track,
    required this.tick,
    required this.labelStyle,
    required this.thumbBorder,
  });

  final List<DateTime> times;
  final int index;
  final int nowIndex;
  final List<bool> loaded;
  final List<double?> rain;
  final String Function(DateTime time) hourLabel;
  final double inset;
  final Color primary;
  final Color future;
  final Color track;
  final Color tick;
  final TextStyle labelStyle;
  final Color thumbBorder;

  static const double _rainTop = 2;
  static const double _rainHeight = 22;
  static const double _trackY = 36;
  static const double _trackHeight = 8;

  @override
  void paint(Canvas canvas, Size size) {
    final count = times.length;
    if (count < 2) return;
    final w = size.width - 2 * inset;
    final step = w / (count - 1);
    double x(int i) => inset + i * step;
    final nowX = x(nowIndex);

    // Rain intensity at the place, one bar per frame.
    for (var i = 0; i < count; i++) {
      final v = i < rain.length ? rain[i] : null;
      if (v == null || v < 0.1) continue;
      final h =
          math.min(1.0, (math.log(v * 10) / math.ln10) / 3.2) * _rainHeight;
      final color = RadarPalette.classes
          .lastWhere((c) => v >= c.$2, orElse: () => RadarPalette.classes.first)
          .$1;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            x(i) - step * .38,
            _rainTop + _rainHeight - math.max(3, h),
            math.max(1.5, step * .76),
            math.max(3, h),
          ),
          const Radius.circular(2),
        ),
        Paint()..color = color,
      );
    }

    final trackRect = Rect.fromLTWH(
      inset,
      _trackY - _trackHeight / 2,
      w,
      _trackHeight,
    );
    const radius = Radius.circular(_trackHeight / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(trackRect, radius),
      Paint()..color = track,
    );

    // Forecast part: tinted and striped.
    final futureRect = Rect.fromLTRB(
      nowX,
      trackRect.top,
      trackRect.right,
      trackRect.bottom,
    );
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(trackRect, radius));
    canvas.drawRect(futureRect, Paint()..color = future.withValues(alpha: .18));
    final stripe = Paint()
      ..color = future.withValues(alpha: .35)
      ..strokeWidth = 2;
    for (var sx = futureRect.left - 10; sx < futureRect.right; sx += 7) {
      canvas.drawLine(
        Offset(sx, futureRect.bottom),
        Offset(sx + 8, futureRect.top),
        stripe,
      );
    }
    // Loaded frames fill the track, so loading progress is visible in place.
    for (var i = 0; i < count; i++) {
      if (!loaded[i]) continue;
      final c = i <= nowIndex ? primary : future;
      canvas.drawRect(
        Rect.fromLTWH(
          x(i) - step / 2,
          trackRect.top,
          step + .5,
          trackRect.height,
        ),
        Paint()..color = c.withValues(alpha: i <= index ? .9 : .4),
      );
    }
    canvas.restore();

    // Ticks every 15 minutes, labels on full hours.
    final tickPaint = Paint()
      ..color = tick
      ..strokeWidth = 1;
    for (var i = 0; i < count; i++) {
      final local = times[i].toLocal();
      if (local.minute % 15 != 0) continue;
      final hour = local.minute == 0;
      canvas.drawLine(
        Offset(x(i), trackRect.bottom + 3),
        Offset(x(i), trackRect.bottom + (hour ? 9 : 6)),
        tickPaint,
      );
      if (hour) {
        _text(
          canvas,
          hourLabel(local),
          Offset(x(i), trackRect.bottom + 11),
          labelStyle,
        );
      }
    }

    // Now marker.
    canvas.drawLine(
      Offset(nowX, _rainTop),
      Offset(nowX, trackRect.bottom + 2),
      Paint()
        ..color = primary.withValues(alpha: .8)
        ..strokeWidth = 2,
    );

    // Thumb.
    final thumb = Offset(x(index), _trackY);
    final thumbColor = index > nowIndex ? future : primary;
    canvas.drawCircle(
      thumb,
      16,
      Paint()..color = thumbColor.withValues(alpha: .18),
    );
    canvas.drawCircle(thumb, 11, Paint()..color = thumbBorder);
    canvas.drawCircle(thumb, 8, Paint()..color = thumbColor);
  }

  void _text(Canvas canvas, String text, Offset at, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(at.dx - tp.width / 2, at.dy));
  }

  @override
  bool shouldRepaint(_SliderPainter old) => true;
}
