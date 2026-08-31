import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:tool_lab/core/tool_page_state.dart';

import '../engine/luma_well_engine.dart';

class LumaWellBoard extends StatefulWidget {
  final LumaWellEngine engine;
  final ValueChanged<bool> onMerge;

  const LumaWellBoard({super.key, required this.engine, required this.onMerge});

  @override
  State<LumaWellBoard> createState() => _LumaWellBoardState();
}

class _LumaWellBoardState extends State<LumaWellBoard>
    with SingleTickerProviderStateMixin, DisposeCleanup {
  late final Ticker _ticker;
  Duration _last = Duration.zero;

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
    final before = widget.engine.merges;
    widget.engine.advance(
      (elapsed - _last).inMicroseconds / Duration.microsecondsPerSecond,
    );
    _last = elapsed;
    if (widget.engine.merges > before) widget.onMerge(true);
  }

  Offset _normalized(Offset position, Size size) {
    final center = size.center(Offset.zero);
    final scale = size.shortestSide / 2;
    return Offset(
      (position.dx - center.dx) / scale,
      (position.dy - center.dy) / scale,
    );
  }

  void _move(Offset position, Size size) {
    final point = _normalized(position, size);
    widget.engine.moveCapture(point.dx, point.dy);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      return GestureDetector(
        onPanDown: (details) {
          final point = _normalized(details.localPosition, size);
          widget.engine.beginCapture(point.dx, point.dy);
        },
        onPanUpdate: (details) => _move(details.localPosition, size),
        onPanEnd: (_) => widget.engine.endCapture(),
        onPanCancel: widget.engine.endCapture,
        child: CustomPaint(
          painter: _LumaFieldPainter(engine: widget.engine),
          child: Stack(
            children: [
              for (final orb in widget.engine.orbs)
                _OrbView(
                  orb: orb,
                  engine: widget.engine,
                  size: size,
                  captured: widget.engine.capturedIds.contains(orb.id),
                ),
              if (widget.engine.isCapturing)
                _CaptureRing(engine: widget.engine, size: size),
            ],
          ),
        ),
      );
    },
  );
}

class _OrbView extends StatelessWidget {
  final LumaOrb orb;
  final LumaWellEngine engine;
  final Size size;
  final bool captured;

  const _OrbView({
    required this.orb,
    required this.engine,
    required this.size,
    required this.captured,
  });

  @override
  Widget build(BuildContext context) {
    final scale = size.shortestSide / 2;
    final diameter = engine.radiusFor(orb) * scale * 2;
    return Positioned(
      left: size.width / 2 + orb.x * scale - diameter / 2,
      top: size.height / 2 + orb.y * scale - diameter / 2,
      width: diameter,
      height: diameter,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: captured ? 1.35 : 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              center: const Alignment(-0.35, -0.4),
              colors: [
                _colorForMass(orb.mass),
                _colorForMass(orb.mass).withValues(alpha: 0.46),
              ],
            ),
            border: Border.all(
              color: captured
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.5),
              width: captured ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _colorForMass(orb.mass).withValues(alpha: 0.55),
                blurRadius: diameter * 0.5,
              ),
            ],
          ),
          child: Center(
            child: Text(
              '${orb.mass.round()}',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CaptureRing extends StatelessWidget {
  final LumaWellEngine engine;
  final Size size;

  const _CaptureRing({required this.engine, required this.size});

  @override
  Widget build(BuildContext context) {
    final scale = size.shortestSide / 2;
    final diameter = scale * 0.46;
    return Positioned(
      left: size.width / 2 + engine.captureX * scale - diameter / 2,
      top: size.height / 2 + engine.captureY * scale - diameter / 2,
      width: diameter,
      height: diameter,
      child: CircularProgressIndicator(
        value: engine.capturedIds.length >= 2 ? engine.captureProgress : null,
        color: Colors.white.withValues(alpha: 0.85),
        strokeWidth: 3,
      ),
    );
  }
}

Color _colorForMass(double mass) {
  if (mass < 3) return const Color(0xFFFFAE3D);
  if (mass < 7) return const Color(0xFFFF744B);
  if (mass < 14) return const Color(0xFFE04E8A);
  return const Color(0xFFB464E8);
}

class _LumaFieldPainter extends CustomPainter {
  final LumaWellEngine engine;

  const _LumaFieldPainter({required this.engine});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final scale = size.shortestSide / 2;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF080A11),
    );
    final star = Paint()..color = Colors.white.withValues(alpha: 0.24);
    for (var i = 0; i < 90; i++) {
      canvas.drawCircle(
        Offset(
          (i * 71 % 997) / 997 * size.width,
          (i * 149 % 991) / 991 * size.height,
        ),
        i % 5 == 0 ? 1.1 : 0.6,
        star,
      );
    }
    final radius = engine.planetRadius * scale;
    final terrain = Paint()
      ..color = const Color(0xFF1C2029)
      ..strokeWidth = 3;
    for (var i = 0; i < 56; i++) {
      final angle = i * math.pi * 2 / 56;
      canvas.drawLine(
        center + Offset(math.cos(angle), math.sin(angle)) * radius * 0.55,
        center + Offset(math.cos(angle), math.sin(angle)) * radius * 1.6,
        terrain,
      );
    }
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF3A414B), Color(0xFF171A21)],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
  }

  @override
  bool shouldRepaint(_LumaFieldPainter oldDelegate) => true;
}
