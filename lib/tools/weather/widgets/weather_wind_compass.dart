import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../weather_colors.dart';

class WeatherWindCompass extends StatelessWidget {
  const WeatherWindCompass({
    super.key,
    required this.direction,
    this.size = 64,
  });

  /// Meteorological direction the wind comes from, in degrees.
  final double? direction;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CustomPaint(
      size: Size.square(size),
      painter: _CompassPainter(
        direction: direction,
        ring: theme.colorScheme.outlineVariant,
        label: theme.textTheme.labelSmall!.copyWith(
          fontSize: 9,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _CompassPainter extends CustomPainter {
  _CompassPainter({
    required this.direction,
    required this.ring,
    required this.label,
  });

  final double? direction;
  final Color ring;
  final TextStyle label;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final tick = Paint()
      ..color = ring
      ..strokeWidth = 1.2;
    for (var i = 0; i < 36; i++) {
      final a = i * math.pi / 18;
      final d = Offset(math.sin(a), -math.cos(a));
      canvas.drawLine(
        c + d * r * (i % 9 == 0 ? .78 : .86),
        c + d * r * .96,
        tick,
      );
    }
    final n = TextPainter(
      text: TextSpan(
        text: 'N',
        style: label.copyWith(fontWeight: FontWeight.w800),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    n.paint(canvas, c + Offset(-n.width / 2, -r * .7));

    final dir = direction;
    if (dir == null) return;
    // Arrow points where the wind blows to.
    final a = (dir + 180) * math.pi / 180;
    final d = Offset(math.sin(a), -math.cos(a));
    final side = Offset(-d.dy, d.dx);
    final tip = c + d * r * .62;
    final tail = c - d * r * .5;
    final paint = Paint()
      ..color = WeatherColors.windLine
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(tail, tip - d * 6, paint);
    canvas.drawPath(
      Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo((tip - d * 12 + side * 7).dx, (tip - d * 12 + side * 7).dy)
        ..lineTo((tip - d * 12 - side * 7).dx, (tip - d * 12 - side * 7).dy)
        ..close(),
      Paint()..color = WeatherColors.windLine,
    );
    canvas.drawCircle(tail, 3.5, Paint()..color = WeatherColors.windLine);
  }

  @override
  bool shouldRepaint(_CompassPainter old) =>
      old.direction != direction || old.ring != ring;
}
