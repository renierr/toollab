import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../models/astronomy.dart';
import '../weather_colors.dart';

class WeatherMoonView extends StatelessWidget {
  const WeatherMoonView({super.key, required this.moon, this.size = 56});

  final MoonState moon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CustomPaint(
      size: Size.square(size),
      painter: _MoonPainter(
        moon: moon,
        dark: theme.colorScheme.surfaceContainerHighest,
      ),
    );
  }
}

class _MoonPainter extends CustomPainter {
  _MoonPainter({required this.moon, required this.dark});

  final MoonState moon;
  final Color dark;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 2;
    canvas.drawCircle(c, r, Paint()..color = dark);
    // Terminator ellipse: half-disc on the lit side plus/minus an ellipse.
    final k = math.cos(2 * math.pi * moon.age / MoonState.synodicMonth);
    final litRight = moon.isWaxing;
    final half = Path()
      ..addArc(
        Rect.fromCircle(center: c, radius: r),
        litRight ? -math.pi / 2 : math.pi / 2,
        math.pi,
      )
      ..close();
    final ellipse = Path()
      ..addOval(
        Rect.fromCenter(center: c, width: 2 * r * k.abs(), height: 2 * r),
      );
    final lit = k > 0
        ? Path.combine(PathOperation.difference, half, ellipse)
        : Path.combine(PathOperation.union, half, ellipse);
    canvas.drawPath(
      lit,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-.3, -.3),
          colors: [Colors.white, WeatherColors.moon],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
  }

  @override
  bool shouldRepaint(_MoonPainter old) =>
      old.moon.age != moon.age || old.dark != dark;
}
