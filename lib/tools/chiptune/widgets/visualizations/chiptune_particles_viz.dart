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
  double angle, radius, speed, baseRadius, size, hue;
  _Particle({
    required this.angle,
    required this.radius,
    required this.speed,
    required this.baseRadius,
    required this.size,
    required this.hue,
  });
}

class _ChiptuneParticlesVizState extends State<ChiptuneParticlesViz> {
  static const int _count = 80;
  final List<_Particle> _particles = [];
  final _rng = math.Random();
  double _cx = 400;
  double _cy = 200;
  double _maxR = 200;
  double _bassPulse = 0;
  double _bassDecay = 0;

  @override
  void initState() {
    super.initState();
    _initParticles();
  }

  void _initParticles() {
    _particles.clear();
    for (int i = 0; i < _count; i++) {
      final t = i / _count;
      _particles.add(
        _Particle(
          angle: _rng.nextDouble() * math.pi * 2,
          radius: 0,
          speed: 0.3 + _rng.nextDouble() * 0.7,
          baseRadius: t * 0.9,
          size: 1.5 + _rng.nextDouble() * 3.5,
          hue: 180 + t * 180,
        ),
      );
    }
  }

  @override
  void didUpdateWidget(ChiptuneParticlesViz oldWidget) {
    super.didUpdateWidget(oldWidget);
    final data = widget.data;
    if (data == null) return;
    if (_particles.isEmpty) _initParticles();

    final dt = data.deltaTime.clamp(0.001, 0.05);
    final bass = (data.bass * 1.5).clamp(0.0, 1.0);

    _bassPulse = math.max(bass, _bassPulse * (1 - dt * 8));
    _bassDecay = _bassDecay * (1 - dt * 4) + bass * dt * 4;

    for (int i = 0; i < _particles.length; i++) {
      final p = _particles[i];
      p.angle += p.speed * dt * (1 + _bassDecay * 0.5);
      if (p.angle > math.pi * 2) p.angle -= math.pi * 2;

      final bin = (i * 128 ~/ _count).clamp(0, 127);
      final freqVal = data.freq[bin];
      final targetRadius =
          p.baseRadius * (1 + freqVal * 0.6) + _bassPulse * 0.25;
      p.radius += (targetRadius - p.radius) * 0.1;

      p.size += (1.5 + freqVal * 5 - p.size) * 0.08;
      p.hue = (p.hue + dt * 15) % 360;
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          _cx = constraints.maxWidth / 2;
          _cy = constraints.maxHeight / 2;
          _maxR = math.min(constraints.maxWidth, constraints.maxHeight) * 0.4;
          return CustomPaint(
            painter: _ParticlesPainter(
              particles: _particles,
              cx: _cx,
              cy: _cy,
              maxR: _maxR,
            ),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _ParticlesPainter extends CustomPainter {
  final List<_Particle> particles;
  final double cx, cy, maxR;
  const _ParticlesPainter({
    required this.particles,
    required this.cx,
    required this.cy,
    required this.maxR,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (maxR <= 0) return;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, cx * 2, cy * 2),
      Paint()..color = ChiptuneColors.visualizerBg,
    );

    for (final p in particles) {
      final r = p.radius * maxR;
      final x = cx + math.cos(p.angle) * r;
      final y = cy + math.sin(p.angle) * r;
      final pos = Offset(x, y);

      final color = HSVColor.fromAHSV(0.7, p.hue, 0.85, 0.9).toColor();

      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.15)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.size * 1.5);
      canvas.drawCircle(pos, p.size * 1.2, glowPaint);

      canvas.drawCircle(pos, p.size, Paint()..color = color);

      canvas.drawCircle(
        pos,
        p.size * 0.35,
        Paint()..color = HSVColor.fromAHSV(0.8, p.hue, 0.1, 1).toColor(),
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlesPainter oldDelegate) => true;
}
