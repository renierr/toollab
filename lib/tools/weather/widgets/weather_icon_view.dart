import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../models/weather_condition.dart';
import '../weather_colors.dart';

class WeatherIconView extends StatefulWidget {
  const WeatherIconView({
    super.key,
    required this.condition,
    required this.isDay,
    this.size = 48,
    this.animate = false,
  });

  final WeatherCondition condition;
  final bool isDay;
  final double size;
  final bool animate;

  @override
  State<WeatherIconView> createState() => _WeatherIconViewState();
}

class _WeatherIconViewState extends State<WeatherIconView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
    value: 0.35,
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(WeatherIconView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animate != widget.animate) _sync();
  }

  void _sync() {
    if (widget.animate) {
      _controller.repeat();
    } else {
      _controller
        ..stop()
        ..value = 0.35;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.square(widget.size),
        painter: WeatherIconPainter(
          condition: widget.condition,
          isDay: widget.isDay,
          animation: _controller,
        ),
      ),
    );
  }
}

class WeatherIconPainter extends CustomPainter {
  WeatherIconPainter({
    required this.condition,
    required this.isDay,
    required this.animation,
  }) : super(repaint: animation);

  final WeatherCondition condition;
  final bool isDay;
  final Animation<double> animation;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final t = animation.value;
    canvas.save();
    canvas.translate((size.width - s) / 2, (size.height - s) / 2);

    switch (condition) {
      case WeatherCondition.clear:
        _celestial(canvas, Offset(s * .5, s * .5), s * .24, t);
      case WeatherCondition.mostlyClear:
        _celestial(canvas, Offset(s * .42, s * .42), s * .21, t);
        _cloud(canvas, Offset(s * .64, s * .7), s * .5, dark: false, drift: t);
      case WeatherCondition.partlyCloudy:
        _celestial(canvas, Offset(s * .36, s * .36), s * .18, t);
        _cloud(
          canvas,
          Offset(s * .56, s * .62),
          s * .72,
          dark: false,
          drift: t,
        );
      case WeatherCondition.cloudy:
        _cloud(
          canvas,
          Offset(s * .62, s * .44),
          s * .55,
          dark: true,
          drift: -t,
        );
        _cloud(
          canvas,
          Offset(s * .44, s * .62),
          s * .72,
          dark: false,
          drift: t,
        );
      case WeatherCondition.overcast:
        _cloud(canvas, Offset(s * .6, s * .42), s * .62, dark: true, drift: -t);
        _cloud(
          canvas,
          Offset(s * .46, s * .6),
          s * .8,
          dark: true,
          drift: t,
          shade: .85,
        );
      case WeatherCondition.fog:
        _cloud(canvas, Offset(s * .5, s * .42), s * .7, dark: true, drift: 0);
        _fog(canvas, s, t);
      case WeatherCondition.thunderstorm:
        _cloud(
          canvas,
          Offset(s * .5, s * .38),
          s * .82,
          dark: true,
          drift: t,
          shade: .7,
        );
        _drops(canvas, s, t, count: 3, color: WeatherColors.rain);
        _bolt(canvas, s, t);
      case WeatherCondition.rainShower ||
          WeatherCondition.sleetShower ||
          WeatherCondition.snowShower:
        _celestial(canvas, Offset(s * .34, s * .3), s * .16, t);
        _cloud(
          canvas,
          Offset(s * .55, s * .44),
          s * .72,
          dark: false,
          drift: t,
        );
        _precipitation(canvas, s, t);
      default:
        _cloud(
          canvas,
          Offset(s * .5, s * .4),
          s * .8,
          dark:
              condition == WeatherCondition.heavyRain ||
              condition == WeatherCondition.heavySnow,
          drift: t,
        );
        _precipitation(canvas, s, t);
    }
    canvas.restore();
  }

  void _precipitation(Canvas canvas, double s, double t) {
    switch (condition) {
      case WeatherCondition.drizzle:
        _drops(canvas, s, t, count: 3, color: WeatherColors.rain, length: .05);
      case WeatherCondition.freezingDrizzle || WeatherCondition.freezingRain:
        _drops(canvas, s, t, count: 3, color: WeatherColors.rain);
        _flakes(canvas, s, t, count: 1, phase: .5);
      case WeatherCondition.lightRain:
        _drops(canvas, s, t, count: 3, color: WeatherColors.rain);
      case WeatherCondition.rain || WeatherCondition.rainShower:
        _drops(canvas, s, t, count: 4, color: WeatherColors.rain);
      case WeatherCondition.heavyRain:
        _drops(canvas, s, t, count: 6, color: WeatherColors.rain, length: .12);
      case WeatherCondition.sleet || WeatherCondition.sleetShower:
        _drops(canvas, s, t, count: 2, color: WeatherColors.rain);
        _flakes(canvas, s, t, count: 2, phase: .5);
      case WeatherCondition.lightSnow:
        _flakes(canvas, s, t, count: 2);
      case WeatherCondition.snow || WeatherCondition.snowShower:
        _flakes(canvas, s, t, count: 3);
      case WeatherCondition.heavySnow:
        _flakes(canvas, s, t, count: 5);
      case WeatherCondition.hail:
        _hail(canvas, s, t);
      default:
        break;
    }
  }

  void _celestial(Canvas canvas, Offset c, double r, double t) {
    if (isDay) {
      _sun(canvas, c, r, t);
    } else {
      _moon(canvas, c, r, t);
    }
  }

  void _sun(Canvas canvas, Offset c, double r, double t) {
    canvas.drawCircle(
      c,
      r * 1.9,
      Paint()
        ..shader = RadialGradient(
          colors: [
            WeatherColors.sun.withValues(alpha: .45),
            WeatherColors.sun.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r * 1.9)),
    );
    final ray = Paint()
      ..color = WeatherColors.sun
      ..strokeWidth = r * .16
      ..strokeCap = StrokeCap.round;
    final turn = t * math.pi / 2;
    for (var i = 0; i < 8; i++) {
      final a = turn + i * math.pi / 4;
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + dir * r * 1.3, c + dir * r * 1.62, ray);
    }
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          colors: [WeatherColors.sunCore, WeatherColors.sun],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
  }

  void _moon(Canvas canvas, Offset c, double r, double t) {
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          WeatherColors.moon.withValues(alpha: .3),
          WeatherColors.moon.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: c, radius: r * 1.8));
    canvas.drawCircle(c, r * 1.8, glow);
    final crescent = Path.combine(
      PathOperation.difference,
      Path()..addOval(Rect.fromCircle(center: c, radius: r)),
      Path()..addOval(
        Rect.fromCircle(center: c + Offset(r * .55, -r * .35), radius: r * .85),
      ),
    );
    canvas.drawPath(crescent, Paint()..color = WeatherColors.moon);
    final star = Paint()..color = WeatherColors.moon;
    for (final (dx, dy, phase) in const [
      (1.3, -.9, 0.0),
      (1.6, .4, .33),
      (.9, 1.2, .66),
    ]) {
      final tw = (math.sin((t + phase) * 2 * math.pi) + 1) / 2;
      star.color = WeatherColors.moon.withValues(alpha: .35 + .65 * tw);
      canvas.drawCircle(c + Offset(dx * r, dy * r), r * (.06 + .05 * tw), star);
    }
  }

  void _cloud(
    Canvas canvas,
    Offset c,
    double w, {
    required bool dark,
    required double drift,
    double shade = 1,
  }) {
    final dx = math.sin(drift * 2 * math.pi) * w * .03;
    final center = c + Offset(dx, 0);
    final h = w * .5;
    final base = Rect.fromCenter(
      center: center + Offset(0, h * .2),
      width: w,
      height: h * .55,
    );
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(base, Radius.circular(h * .28)))
      ..addOval(
        Rect.fromCircle(
          center: center + Offset(-w * .2, h * .02),
          radius: h * .34,
        ),
      )
      ..addOval(
        Rect.fromCircle(
          center: center + Offset(w * .06, -h * .16),
          radius: h * .46,
        ),
      )
      ..addOval(
        Rect.fromCircle(
          center: center + Offset(w * .3, h * .08),
          radius: h * .3,
        ),
      );
    final bounds = path.getBounds();
    final top = dark ? WeatherColors.cloudDark : WeatherColors.cloudLight;
    final bottom = dark
        ? Color.lerp(WeatherColors.cloudDark, Colors.black, .25 * (2 - shade))!
        : const Color(0xFFD5DEEA);
    canvas.drawPath(
      path.shift(Offset(0, h * .06)),
      Paint()
        ..color = Colors.black.withValues(alpha: .12)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, h * .08),
    );
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top, bottom],
        ).createShader(bounds),
    );
  }

  void _drops(
    Canvas canvas,
    double s,
    double t, {
    required int count,
    required Color color,
    double length = .09,
  }) {
    final paint = Paint()
      ..strokeWidth = s * .045
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < count; i++) {
      final x = s * (.3 + .4 * (count == 1 ? .5 : i / (count - 1)));
      final p = (t * 1.5 + i * .37) % 1;
      final y = s * (.64 + p * .28);
      paint.color = color.withValues(alpha: 1 - p * .7);
      canvas.drawLine(Offset(x, y), Offset(x - s * .03, y + s * length), paint);
    }
  }

  void _flakes(
    Canvas canvas,
    double s,
    double t, {
    required int count,
    double phase = 0,
  }) {
    final paint = Paint()
      ..color = WeatherColors.snow
      ..strokeWidth = s * .025
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < count; i++) {
      final p = (t + i * .41 + phase) % 1;
      final x =
          s * (.32 + .36 * (count == 1 ? .5 : i / (count - 1))) +
          math.sin((p + i) * 2 * math.pi) * s * .03;
      final y = s * (.66 + p * .26);
      final r = s * .045;
      paint.color = WeatherColors.snow.withValues(alpha: 1 - p * .6);
      for (var k = 0; k < 3; k++) {
        final a = k * math.pi / 3 + p * math.pi;
        final d = Offset(math.cos(a), math.sin(a)) * r;
        canvas.drawLine(Offset(x, y) - d, Offset(x, y) + d, paint);
      }
    }
  }

  void _hail(Canvas canvas, double s, double t) {
    final paint = Paint()..color = WeatherColors.snow;
    for (var i = 0; i < 4; i++) {
      final p = (t * 1.6 + i * .29) % 1;
      paint.color = WeatherColors.snow.withValues(alpha: 1 - p * .6);
      canvas.drawCircle(
        Offset(s * (.3 + i * .13), s * (.66 + p * .26)),
        s * .035,
        paint,
      );
    }
  }

  void _fog(Canvas canvas, double s, double t) {
    final paint = Paint()
      ..strokeWidth = s * .05
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      final shift = math.sin((t + i * .3) * 2 * math.pi) * s * .05;
      paint.color = WeatherColors.fog.withValues(alpha: .9 - i * .2);
      final y = s * (.68 + i * .1);
      canvas.drawLine(
        Offset(s * (.2 + i * .04) + shift, y),
        Offset(s * (.8 - i * .04) + shift, y),
        paint,
      );
    }
  }

  void _bolt(Canvas canvas, double s, double t) {
    final flash = t % .5 < .08 || (t % .5 > .14 && t % .5 < .18);
    final path = Path()
      ..moveTo(s * .52, s * .55)
      ..lineTo(s * .4, s * .76)
      ..lineTo(s * .5, s * .76)
      ..lineTo(s * .43, s * .95)
      ..lineTo(s * .64, s * .69)
      ..lineTo(s * .53, s * .69)
      ..lineTo(s * .6, s * .55)
      ..close();
    if (flash) {
      canvas.drawPath(
        path,
        Paint()
          ..color = WeatherColors.lightning.withValues(alpha: .6)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * .05),
      );
    }
    canvas.drawPath(path, Paint()..color = WeatherColors.lightning);
  }

  @override
  bool shouldRepaint(WeatherIconPainter old) =>
      old.condition != condition ||
      old.isDay != isDay ||
      old.animation != animation;
}
