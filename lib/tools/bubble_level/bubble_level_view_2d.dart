import 'dart:math' as math;
import 'package:flutter/material.dart';

class BubbleLevelView2d extends StatelessWidget {
  final double normalizedPitch;
  final double normalizedRoll;
  final bool locked;
  final Color accentColor;

  const BubbleLevelView2d({
    super.key,
    required this.normalizedPitch,
    required this.normalizedRoll,
    required this.locked,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.maxWidth;
          return SizedBox(
            width: size,
            height: size,
            child: ClipOval(
              child: CustomPaint(
                painter: _Bubble2dPainter(
                  normalizedPitch: normalizedPitch,
                  normalizedRoll: normalizedRoll,
                  locked: locked,
                  accentColor: accentColor,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Bubble2dPainter extends CustomPainter {
  final double normalizedPitch;
  final double normalizedRoll;
  final bool locked;
  final Color accentColor;

  _Bubble2dPainter({
    required this.normalizedPitch,
    required this.normalizedRoll,
    required this.locked,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerR = size.width / 2;
    final bubbleMaxOffset = outerR * 0.42;

    final bgPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, 0),
        radius: 1,
        colors: [
          HSLColor.fromColor(
            accentColor,
          ).withLightness(0.55).toColor().withAlpha(30),
          accentColor.withAlpha(10),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: outerR));
    canvas.drawCircle(center, outerR, bgPaint);

    final borderPaint = Paint()
      ..color = accentColor.withAlpha(80)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, outerR, borderPaint);

    const ringFractions = [0.20, 0.50, 0.78];
    final ringPaint = Paint()
      ..color = accentColor.withAlpha(35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final f in ringFractions) {
      canvas.drawCircle(center, outerR * f, ringPaint);
    }

    final crossPaint = Paint()
      ..color = accentColor.withAlpha(45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(center.dx - outerR * 0.84, center.dy),
      Offset(center.dx + outerR * 0.84, center.dy),
      crossPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - outerR * 0.84),
      Offset(center.dx, center.dy + outerR * 0.84),
      crossPaint,
    );

    final bubbleX =
        BubbleLevelSensorClamp.clamp(normalizedRoll, -1, 1) * bubbleMaxOffset;
    final bubbleY =
        BubbleLevelSensorClamp.clamp(normalizedPitch, -1, 1) * bubbleMaxOffset;
    final bc = Offset(center.dx + bubbleX, center.dy + bubbleY);
    final br = outerR * 0.18;

    final bubblePaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.3),
        radius: 1,
        colors: [
          const Color(0xFFF7FFD8),
          const Color(0xFFB9FF79),
          const Color(0xFF65DE42),
          if (locked) const Color(0xFF309A29) else const Color(0xFF888888),
        ],
        stops: const [0, 0.42, 0.72, 1],
      ).createShader(Rect.fromCircle(center: bc, radius: br));
    canvas.drawCircle(bc, br, bubblePaint);

    final glowPaint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12)
      ..color = locked
          ? const Color(0xFFA4FF80).withAlpha(160)
          : const Color(0xFF7EFF57).withAlpha(100);
    canvas.drawCircle(bc, br * 0.8, glowPaint);

    final highlightPaint = Paint()
      ..color = Colors.white.withAlpha(90)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(bc.dx - br * 0.25, bc.dy - br * 0.25),
      br * 0.35,
      highlightPaint,
    );

    if (locked) {
      final lockRingPaint = Paint()
        ..color = accentColor.withAlpha(80)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(center, outerR * 0.08, lockRingPaint);
    }
  }

  @override
  bool shouldRepaint(_Bubble2dPainter old) =>
      old.normalizedPitch != normalizedPitch ||
      old.normalizedRoll != normalizedRoll ||
      old.locked != locked;
}

class BubbleLevelSensorClamp {
  static double clamp(double value, double min, double max) {
    return math.min(max, math.max(min, value));
  }
}
