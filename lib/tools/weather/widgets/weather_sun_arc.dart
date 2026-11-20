import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../weather_colors.dart';

class WeatherSunArc extends StatelessWidget {
  const WeatherSunArc({
    super.key,
    required this.sunrise,
    required this.sunset,
    required this.now,
    this.width = 96,
  });

  final DateTime sunrise;
  final DateTime sunset;
  final DateTime now;
  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CustomPaint(
      size: Size(width, width * .58),
      painter: _SunArcPainter(
        progress:
            now.difference(sunrise).inSeconds /
            math.max(1, sunset.difference(sunrise).inSeconds),
        track: theme.colorScheme.outlineVariant,
      ),
    );
  }
}

class _SunArcPainter extends CustomPainter {
  _SunArcPainter({required this.progress, required this.track});

  final double progress;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final r = math.min(size.width / 2, size.height) - 6;
    final c = Offset(size.width / 2, size.height - 4);
    final rect = Rect.fromCircle(center: c, radius: r);
    final dash = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (var a = 0.0; a < math.pi; a += .16) {
      canvas.drawArc(rect, math.pi + a, .08, false, dash);
    }
    canvas.drawLine(
      Offset(c.dx - r - 6, c.dy),
      Offset(c.dx + r + 6, c.dy),
      dash,
    );
    final p = progress.clamp(0.0, 1.0);
    if (progress > 0 && progress < 1) {
      canvas.drawArc(
        rect,
        math.pi,
        math.pi * p,
        false,
        Paint()
          ..shader = const LinearGradient(
            colors: [WeatherColors.sunCore, WeatherColors.sun],
          ).createShader(rect)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    }
    final a = math.pi + math.pi * p;
    final sun = c + Offset(math.cos(a), math.sin(a)) * r;
    final up = progress > 0 && progress < 1;
    canvas.drawCircle(
      sun,
      9,
      Paint()..color = WeatherColors.sun.withValues(alpha: up ? .3 : .1),
    );
    canvas.drawCircle(
      sun,
      5.5,
      Paint()..color = up ? WeatherColors.sun : track,
    );
  }

  @override
  bool shouldRepaint(_SunArcPainter old) =>
      old.progress != progress || old.track != track;
}
