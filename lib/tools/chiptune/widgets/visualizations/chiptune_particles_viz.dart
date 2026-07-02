import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../chiptune_colors.dart';
import 'chiptune_viz_data.dart';

class ChiptuneParticlesViz extends StatefulWidget {
  final VizData? data;
  const ChiptuneParticlesViz({super.key, this.data});

  @override
  State<ChiptuneParticlesViz> createState() => _ChiptuneParticlesVizState();
}

class _Particle {
  double x, y, vx, vy, size, hue, life, maxLife;
  _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.hue,
    required this.life,
    required this.maxLife,
  });
}

class _ChiptuneParticlesVizState extends State<ChiptuneParticlesViz> {
  static const int _count = 120;
  final List<_Particle> _particles = [];
  final _rng = math.Random();

  _Particle _spawn(double w, double h) {
    final maxLife = 3 + _rng.nextDouble() * 4;
    return _Particle(
      x: _rng.nextDouble() * w,
      y: _rng.nextDouble() * h,
      vx: (_rng.nextDouble() - 0.5) * 60,
      vy: (_rng.nextDouble() - 0.5) * 60,
      size: 1 + _rng.nextDouble() * 4,
      hue: _rng.nextDouble() * 360,
      life: maxLife,
      maxLife: maxLife,
    );
  }

  @override
  void didUpdateWidget(ChiptuneParticlesViz oldWidget) {
    super.didUpdateWidget(oldWidget);
    final data = widget.data;
    if (data == null) return;
    if (_particles.isEmpty) {
      for (int i = 0; i < _count; i++) {
        _particles.add(_spawn(400, 200));
      }
    }

    final dt = data.deltaTime.clamp(0.001, 0.05);
    final bassPush = 1 + data.bass * 5;
    final freqAvg = data.freq.reduce((a, b) => a + b) / data.freq.length;
    final jitter = freqAvg * 80;

    for (int i = 0; i < _particles.length; i++) {
      final p = _particles[i];
      p.x += p.vx * dt * bassPush;
      p.y += p.vy * dt * bassPush;

      p.vx += data.wave[(i * 8) % 256] * jitter * dt;
      p.vy += data.wave[(i * 8 + 4) % 256] * jitter * dt;

      p.vx *= 0.98;
      p.vy *= 0.98;

      final speedLimit = 120 + data.bass * 200;
      final spd = math.sqrt(p.vx * p.vx + p.vy * p.vy);
      if (spd > speedLimit) {
        p.vx = p.vx / spd * speedLimit;
        p.vy = p.vy / spd * speedLimit;
      }

      p.hue = (p.hue + data.bass * 20 * dt) % 360;
      p.life -= dt * (0.3 + data.bass * 0.5);

      if (p.life <= 0 || p.x < -50 || p.x > 500 || p.y < -50 || p.y > 300) {
        _particles[i] = _spawn(400, 200);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _ParticlesPainter(particles: _particles),
        size: Size.infinite,
      ),
    );
  }
}

class _ParticlesPainter extends CustomPainter {
  final List<_Particle> particles;
  const _ParticlesPainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = ChiptuneColors.visualizerBg,
    );

    final blur = MaskFilter.blur(BlurStyle.normal, 8);

    for (final p in particles) {
      final lifeRatio = (p.life / p.maxLife).clamp(0.0, 1.0);
      final alpha = lifeRatio * 0.85;

      final color = HSVColor.fromAHSV(alpha, p.hue, 0.9, 0.9).toColor();
      final pos = Offset(p.x * w / 400, p.y * h / 200);

      final glowPaint = Paint()
        ..color = color.withValues(alpha: alpha * 0.25)
        ..maskFilter = blur;
      canvas.drawCircle(pos, p.size * 2, glowPaint);

      canvas.drawCircle(pos, p.size, Paint()..color = color);

      canvas.drawCircle(
        pos,
        p.size * 0.5,
        Paint()..color = HSVColor.fromAHSV(alpha, p.hue, 0.2, 1).toColor(),
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlesPainter oldDelegate) => true;
}
