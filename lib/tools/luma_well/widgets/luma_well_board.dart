import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_page_state.dart';

import '../engine/luma_well_engine.dart';
import '../luma_well_colors.dart';
import '../luma_well_state.dart';

const double _minOrbDiameter = 26;

class LumaWellBoard extends StatefulWidget {
  final LumaWellEngine engine;
  final bool isActive;
  final void Function(
    LumaWellPowerOrbEffect? powerOrbEffect,
    bool stageUp,
    bool volatileDrained,
  )
  onMerge;

  const LumaWellBoard({
    super.key,
    required this.engine,
    required this.isActive,
    required this.onMerge,
  });

  @override
  State<LumaWellBoard> createState() => _LumaWellBoardState();
}

class _LumaWellBoardState extends State<LumaWellBoard>
    with SingleTickerProviderStateMixin, DisposeCleanup {
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  int _lastPowerCollectedToken = 0;

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
    final before = widget.engine.merges;
    final beforeStage = widget.engine.stage;
    widget.engine.advance(
      (elapsed - _last).inMicroseconds / Duration.microsecondsPerSecond,
    );
    _last = elapsed;
    if (widget.engine.merges > before) {
      final powerCollected =
          widget.engine.powerCollectedToken != _lastPowerCollectedToken;
      _lastPowerCollectedToken = widget.engine.powerCollectedToken;
      widget.onMerge(
        powerCollected ? widget.engine.lastPowerOrbEffect : null,
        widget.engine.stage > beforeStage,
        widget.engine.lastMergeHadVolatile,
      );
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

  Offset _touchAdjusted(Offset position) {
    final settings = context.read<LumaWellState>();
    final direction = settings.touchOffsetDirection;
    if (direction == LumaWellTouchOffsetDirection.none) return position;
    return position + direction.vector * settings.touchOffsetDistance;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      return GestureDetector(
        onPanDown: (details) {
          final point = _normalized(
            _touchAdjusted(details.localPosition),
            size,
          );
          widget.engine.beginCapture(point.dx, point.dy);
        },
        onPanUpdate: (details) {
          final point = _normalized(
            _touchAdjusted(details.localPosition),
            size,
          );
          widget.engine.moveCapture(point.dx, point.dy);
        },
        onPanEnd: (_) => widget.engine.endCapture(),
        onPanCancel: widget.engine.endCapture,
        child: CustomPaint(
          painter: _LumaFieldPainter(
            planetRadius: widget.engine.planetRadius,
            stage: widget.engine.stage,
          ),
          child: Stack(
            children: [
              for (final orb in widget.engine.orbs)
                _OrbView(
                  key: ValueKey(orb.id),
                  orb: orb,
                  engine: widget.engine,
                  size: size,
                  captured: widget.engine.capturedIds.contains(orb.id),
                ),
              if (widget.engine.isCapturing)
                _CaptureRing(engine: widget.engine, size: size),
              _MergeFlight(engine: widget.engine, size: size),
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
    super.key,
    required this.orb,
    required this.engine,
    required this.size,
    required this.captured,
  });

  @override
  Widget build(BuildContext context) {
    final scale = size.shortestSide / 2;
    final diameter = math.max(
      engine.radiusFor(orb) * scale * 2,
      _minOrbDiameter,
    );
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
                _colorForOrb(orb),
                _colorForOrb(orb).withValues(alpha: 0.46),
              ],
            ),
            border: Border.all(
              color: captured
                  ? LumaWellColors.orbBorder
                  : LumaWellColors.orbBorder.withValues(alpha: 0.5),
              width: captured ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _colorForOrb(orb).withValues(alpha: 0.8),
                blurRadius: diameter * 0.8,
              ),
            ],
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  orb.isVolatile
                      ? '✕'
                      : orb.isPower
                      ? '✦'
                      : '${orb.kind + 1}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: orb.isVolatile
                        ? LumaWellColors.volatileLabel
                        : LumaWellColors.orbLabel,
                    fontWeight: FontWeight.w800,
                  ),
                ),
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
    final diameter = scale * engine.captureRadius * 2;
    final hasGroup = engine.capturedIds.length >= 2;
    return Positioned(
      left: size.width / 2 + engine.captureX * scale - diameter / 2,
      top: size.height / 2 + engine.captureY * scale - diameter / 2,
      width: diameter,
      height: diameter,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CustomPaint(
              painter: _CaptureRingPainter(
                progress: engine.captureBlocked || !hasGroup
                    ? 0
                    : engine.captureProgress,
                baseColor: engine.captureBlocked
                    ? LumaWellColors.ringBlocked.withValues(alpha: 0.8)
                    : LumaWellColors.ringNormal.withValues(alpha: 0.32),
                progressColor: engine.captureBlocked
                    ? LumaWellColors.ringBlocked.withValues(alpha: 0.85)
                    : LumaWellColors.ringNormal.withValues(alpha: 0.9),
                blocked: engine.captureBlocked,
              ),
            ),
          ),
          Text(
            '${engine.captureTime.toStringAsFixed(2)}s',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: LumaWellColors.ringNormal,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _CaptureRingPainter extends CustomPainter {
  final double progress;
  final Color baseColor;
  final Color progressColor;
  final bool blocked;

  const _CaptureRingPainter({
    required this.progress,
    required this.baseColor,
    required this.progressColor,
    required this.blocked,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 4;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = baseColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    if (blocked || progress <= 0) return;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * progress.clamp(0.0, 1.0),
      false,
      Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_CaptureRingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.blocked != blocked ||
      oldDelegate.baseColor != baseColor;
}

class _MergeFlight extends StatelessWidget {
  final LumaWellEngine engine;
  final Size size;

  const _MergeFlight({required this.engine, required this.size});

  @override
  Widget build(BuildContext context) {
    final scale = size.shortestSide / 2;
    return TweenAnimationBuilder<double>(
      key: ValueKey(engine.mergeToken),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 680),
      curve: Curves.easeInCubic,
      builder: (context, value, child) {
        if (engine.mergeToken == 0) return const SizedBox.shrink();
        final x = engine.mergeX * (1 - value);
        final y = engine.mergeY * (1 - value);
        final diameter = (26 - value * 16).clamp(8.0, 26.0);
        return Stack(
          children: [
            Positioned(
              left: size.width / 2 + x * scale - diameter / 2,
              top: size.height / 2 + y * scale - diameter / 2,
              width: diameter,
              height: diameter,
              child: Opacity(
                opacity: 1 - value,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: LumaWellColors.powerCharge,
                    boxShadow: [
                      BoxShadow(
                        color: LumaWellColors.mergeGlow.withValues(alpha: 0.8),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: size.width / 2 - 40,
              top: size.height / 2 - 40 - value * 20,
              width: 80,
              child: Opacity(
                opacity: 1 - value,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '+${engine.mergePoints}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: LumaWellColors.powerCharge,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (engine.combo >= 2)
                      Text(
                        'x${engine.combo}',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: LumaWellColors.comboBadge,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

Color _colorForOrb(LumaOrb orb) {
  if (orb.isVolatile) return LumaWellColors.volatileOrb;
  if (!orb.isPower) return LumaWellColors.orbKindColor(orb.kind);
  return switch (orb.power) {
    LumaWellPower.expandField => LumaWellColors.powerExpand,
    LumaWellPower.focusField => LumaWellColors.powerFocus,
    _ => LumaWellColors.powerCharge,
  };
}

class _LumaFieldPainter extends CustomPainter {
  final double planetRadius;
  final int stage;

  const _LumaFieldPainter({required this.planetRadius, required this.stage});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final scale = size.shortestSide / 2;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = LumaWellColors.fieldBackground,
    );
    final star = Paint()
      ..color = LumaWellColors.starDust.withValues(alpha: 0.24);
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
    final radius = planetRadius * scale;
    final core = LumaWellColors.planetCoreForStage(stage);
    final shadow = LumaWellColors.planetShadowForStage(stage);
    if (stage >= 5) {
      canvas.drawCircle(
        center,
        radius * 1.35,
        Paint()..color = core.withValues(alpha: 0.22),
      );
    }
    if (stage >= 3) {
      canvas.drawCircle(
        center,
        radius * 1.6,
        Paint()
          ..color = core.withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    final terrain = Paint()
      ..color = LumaWellColors.terrain
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
        ..shader = RadialGradient(
          colors: [core, shadow],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
  }

  @override
  bool shouldRepaint(_LumaFieldPainter oldDelegate) =>
      oldDelegate.planetRadius != planetRadius ||
      oldDelegate.stage != stage;
}
