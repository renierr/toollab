import 'package:flutter/material.dart';

import '../chaindrop_colors.dart';
import '../engine/chaindrop_engine.dart';

/// One disc — numbered discs show their value, cracked discs show one crack
/// line at stage 0 and two at stage 1.
class ChainDropDiscView extends StatelessWidget {
  final ChainDropDisc disc;
  final double size;

  const ChainDropDiscView({super.key, required this.disc, required this.size});

  @override
  Widget build(BuildContext context) {
    final value = disc.value;
    final color = value != null
        ? ChainDropColors.forValue(value)
        : (disc.crackStage == 0
              ? ChainDropColors.crackedStage0
              : ChainDropColors.crackedStage1);
    final highlight = Color.lerp(color, Colors.white, 0.2)!;
    final shade = Color.lerp(color, Colors.black, 0.24)!;

    Widget body = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [highlight, color, shade],
          stops: const [0, 0.58, 1],
        ),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.22),
          width: size * 0.035,
        ),
        boxShadow: disc.popping
            ? [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.75),
                  blurRadius: size * 0.3,
                  spreadRadius: size * 0.04,
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: size * 0.12,
                  offset: Offset(0, size * 0.045),
                ),
              ],
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: size * 0.022,
          ),
        ),
        child: Center(
          child: value != null
              ? FittedBox(
                  child: Padding(
                    padding: EdgeInsets.all(size * 0.2),
                    child: Text(
                      '$value',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: size * 0.06,
                            offset: Offset(0, size * 0.025),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : CustomPaint(
                  size: Size(size, size),
                  painter: _CrackPainter(stage: disc.crackStage),
                ),
        ),
      ),
    );

    if (disc.spawned) {
      body = _Grow(key: ValueKey('spawn-${disc.id}'), child: body);
    } else if (disc.popping) {
      body = _Flash(key: ValueKey('pop-${disc.id}'), child: body);
    }
    return SizedBox(width: size, height: size, child: body);
  }
}

/// Scales a newly placed disc in from nothing.
class _Grow extends StatelessWidget {
  final Widget child;

  const _Grow({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.1, end: 1),
      duration: const Duration(milliseconds: 170),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: child,
    );
  }
}

/// Briefly overshoots so a disc marked for removal reads as popped rather
/// than merely disappearing.
class _Flash extends StatelessWidget {
  final Widget child;

  const _Flash({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1, end: 1.2),
      duration: const Duration(milliseconds: 190),
      curve: Curves.easeOutCubic,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: child,
    );
  }
}

class _CrackPainter extends CustomPainter {
  final int stage;

  const _CrackPainter({required this.stage});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.45)
      ..strokeWidth = size.width * 0.045
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final w = size.width;
    final h = size.height;

    canvas.drawPath(
      Path()
        ..moveTo(w * 0.3, h * 0.25)
        ..lineTo(w * 0.45, h * 0.5)
        ..lineTo(w * 0.35, h * 0.75),
      paint,
    );

    if (stage >= 1) {
      canvas.drawPath(
        Path()
          ..moveTo(w * 0.7, h * 0.2)
          ..lineTo(w * 0.55, h * 0.48)
          ..lineTo(w * 0.68, h * 0.8),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CrackPainter oldDelegate) =>
      oldDelegate.stage != stage;
}
