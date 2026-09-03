import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../drift_bloom_colors.dart';
import '../engine/drift_bloom_engine.dart';

class DriftBloomBoard extends StatefulWidget {
  final DriftBloomEngine engine;
  final bool isActive;
  final void Function(bool golden) onBloom;

  const DriftBloomBoard({
    super.key,
    required this.engine,
    required this.isActive,
    required this.onBloom,
  });

  @override
  State<DriftBloomBoard> createState() => _DriftBloomBoardState();
}

class _DriftBloomBoardState extends State<DriftBloomBoard>
    with SingleTickerProviderStateMixin, DisposeCleanup {
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  int _lastBloomToken = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_advance)..start();
    onDispose(_ticker.dispose);
  }

  void _advance(Duration elapsed) {
    if (_last == Duration.zero) {
      _last = elapsed;
      return;
    }
    if (!widget.isActive) {
      _last = elapsed;
      return;
    }
    widget.engine.advance(
      (elapsed - _last).inMicroseconds / Duration.microsecondsPerSecond,
    );
    _last = elapsed;
    if (widget.engine.bloomToken != _lastBloomToken) {
      _lastBloomToken = widget.engine.bloomToken;
      widget.onBloom(widget.engine.lastBloomGolden);
    }
  }

  Offset _normalized(Offset position, Size size) {
    final center = size.center(Offset.zero);
    final scale = size.shortestSide / 2;
    return Offset(
      (position.dx - center.dx) / scale,
      (position.dy - center.dy) / scale,
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      return GestureDetector(
        onPanDown: (details) {
          final point = _normalized(details.localPosition, size);
          widget.engine.steer(point.dx, point.dy);
        },
        onPanUpdate: (details) {
          final point = _normalized(details.localPosition, size);
          widget.engine.steer(point.dx, point.dy);
        },
        onPanEnd: (_) => widget.engine.steer(null, null),
        onPanCancel: () => widget.engine.steer(null, null),
        child: CustomPaint(
          painter: _DriftBloomPainter(engine: widget.engine),
          child: Stack(
            children: [
              _BloomFlash(engine: widget.engine, size: size),
              _CoachHint(engine: widget.engine),
            ],
          ),
        ),
      );
    },
  );
}

class _BloomFlash extends StatelessWidget {
  final DriftBloomEngine engine;
  final Size size;

  const _BloomFlash({required this.engine, required this.size});

  @override
  Widget build(BuildContext context) {
    final scale = size.shortestSide / 2;
    return TweenAnimationBuilder<double>(
      key: ValueKey(engine.bloomToken),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        if (engine.bloomToken == 0) return const SizedBox.shrink();
        final diameter = 16 + (size.shortestSide * 0.35 - 16) * value;
        return Positioned(
          left: size.width / 2 + engine.bloomX * scale - diameter / 2,
          top: size.height / 2 + engine.bloomY * scale - diameter / 2,
          width: diameter,
          height: diameter,
          child: Opacity(
            opacity: (1 - value).clamp(0.0, 1.0),
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: DriftBloomColors.bloom, width: 3),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CoachHint extends StatelessWidget {
  final DriftBloomEngine engine;

  const _CoachHint({required this.engine});

  @override
  Widget build(BuildContext context) {
    if (engine.petals > 0) return const SizedBox.shrink();
    return IgnorePointer(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          margin: const EdgeInsets.only(bottom: 24),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Text(
            AppLocalizations.of(context).driftBloomCoachHint,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _DriftBloomPainter extends CustomPainter {
  final DriftBloomEngine engine;

  const _DriftBloomPainter({required this.engine});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final scale = size.shortestSide / 2;
    Offset toPx(double x, double y) =>
        Offset(center.dx + x * scale, center.dy + y * scale);

    final night = engine.nightFactor;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(
              DriftBloomColors.skyTop,
              DriftBloomColors.nightSkyTop,
              night,
            )!,
            Color.lerp(
              DriftBloomColors.fieldBackground,
              DriftBloomColors.nightSkyBottom,
              night,
            )!,
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.drawCircle(
      Offset(size.width * 0.82, size.height * 0.16),
      size.shortestSide * 0.3,
      Paint()
        ..color = DriftBloomColors.skyGlow.withValues(
          alpha: 0.16 * (1 - night),
        ),
    );
    for (var i = 0; i < 24; i++) {
      final drift = (engine.time * (0.02 + (i % 5) * 0.008) + i * 0.37) % 1.4;
      final x = ((i * 311 % 1000) / 1000 * 2.4 - 1.2 + drift).clamp(-1.2, 1.2);
      final y = ((i * 197 % 1000) / 1000 * 2.4 - 1.2).clamp(-1.2, 1.2);
      final twinkle = 0.5 + 0.5 * math.sin(engine.time * 1.2 + i * 2.1);
      final moteColor = Color.lerp(
        DriftBloomColors.mote,
        DriftBloomColors.star,
        night,
      )!;
      canvas.drawCircle(
        toPx(x, y),
        i % 4 == 0 ? 1.6 : 1.0,
        Paint()
          ..color = moteColor.withValues(
            alpha: 0.08 + 0.14 * twinkle + night * 0.2,
          ),
      );
    }
    for (var i = 0; i < 5; i++) {
      final yy = -0.9 + i * 0.45;
      final xx = (engine.time * 0.25 + i * 0.53) % 2.4 - 1.2;
      canvas.drawLine(
        toPx(xx - 0.09, yy),
        toPx(xx + 0.09, yy),
        Paint()
          ..color = DriftBloomColors.streak.withValues(alpha: 0.18)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
    }
    for (final ring in engine.rings) {
      final fade = 1 - (ring.age / ring.life).clamp(0.0, 1.0);
      final breathe = 1 + 0.05 * math.sin(engine.time * 2 + ring.id * 1.3);
      final pos = toPx(ring.x, ring.y);
      final outer = ring.golden
          ? DriftBloomColors.ringInner
          : DriftBloomColors.ring;
      canvas.drawCircle(
        pos,
        ring.radius * breathe * scale,
        Paint()
          ..color = outer.withValues(alpha: 0.7 * fade)
          ..style = PaintingStyle.stroke
          ..strokeWidth = ring.golden ? 3.5 : 2.5,
      );
      canvas.drawCircle(
        pos,
        ring.radius * 0.4 / breathe * scale,
        Paint()
          ..color = DriftBloomColors.ringInner.withValues(alpha: 0.55 * fade)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      if (ring.grazed) {
        canvas.drawCircle(
          pos,
          ring.radius * breathe * scale,
          Paint()
            ..color = DriftBloomColors.ringInner.withValues(alpha: 0.22 * fade),
        );
      }
    }
    final trail = engine.trail;
    for (var i = 0; i < trail.length; i++) {
      final t = (i + 1) / trail.length;
      canvas.drawCircle(
        toPx(trail[i].x, trail[i].y),
        2 + 6 * t,
        Paint()
          ..color = DriftBloomColors.seedGlow.withValues(alpha: 0.05 + 0.2 * t),
      );
    }
    for (final particle in engine.particles) {
      final t = 1 - (particle.age / particle.life).clamp(0.0, 1.0);
      canvas.drawCircle(
        toPx(particle.x, particle.y),
        3.5 * t + 1,
        Paint()..color = DriftBloomColors.bloom.withValues(alpha: 0.85 * t),
      );
    }
    final seedPos = toPx(engine.seedX, engine.seedY);
    final shownPetals = math.min(engine.petals, 12);
    for (var i = 0; i < shownPetals; i++) {
      final angle = i * math.pi * 2 / 12 + engine.time * 0.5;
      canvas.drawCircle(
        seedPos + Offset(math.cos(angle), math.sin(angle)) * 17,
        5,
        Paint()..color = DriftBloomColors.petal,
      );
    }
    canvas.drawCircle(
      seedPos,
      13,
      Paint()..color = DriftBloomColors.seedGlow.withValues(alpha: 0.35),
    );
    canvas.drawCircle(seedPos, 8, Paint()..color = DriftBloomColors.seed);
  }

  @override
  bool shouldRepaint(_DriftBloomPainter oldDelegate) => true;
}
