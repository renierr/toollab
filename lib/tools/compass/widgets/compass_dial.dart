import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../compass_colors.dart';

class CompassDial extends StatelessWidget {
  final double heading; // in degrees
  final double pitch; // in radians
  final double roll; // in radians

  const CompassDial({
    super.key,
    required this.heading,
    required this.pitch,
    required this.roll,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.0,
      child: Container(
        margin: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: CompassColors.shadowColor.withValues(alpha: 0.3),
              blurRadius: 24,
              spreadRadius: 4,
              offset: Offset(
                roll.clamp(-0.5, 0.5) * 20.0,
                pitch.clamp(-0.5, 0.5) * 20.0,
              ),
            ),
          ],
        ),
        child: ClipOval(
          child: CustomPaint(
            painter: _CompassDialPainter(
              heading: heading,
              pitch: pitch,
              roll: roll,
            ),
          ),
        ),
      ),
    );
  }
}

class _CompassDialPainter extends CustomPainter {
  final double heading;
  final double pitch;
  final double roll;

  _CompassDialPainter({
    required this.heading,
    required this.pitch,
    required this.roll,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double radius = math.min(size.width, size.height) / 2;
    final Offset center = Offset(size.width / 2, size.height / 2);

    final double headingRad = heading * math.pi / 180;

    // Calculate parallax offsets based on pitch and roll
    // Limit displacement to keep it within safe visual bounds
    final double maxDisplacement = radius * 0.08;
    final double dxBackground = (roll * 1.5).clamp(-1.0, 1.0) * maxDisplacement;
    final double dyBackground =
        (pitch * 1.5).clamp(-1.0, 1.0) * maxDisplacement;

    final double dxMiddle = (roll * 0.7).clamp(-1.0, 1.0) * maxDisplacement;
    final double dyMiddle = (pitch * 0.7).clamp(-1.0, 1.0) * maxDisplacement;

    // 1. Draw Outer Bezel & Shadow (Stationary, flat on screen)
    final Paint bezelPaint = Paint()
      ..color = CompassColors.dialBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0;
    canvas.drawCircle(center, radius - 3, bezelPaint);

    // 2. Draw Backplate Face (Shifted for depth parallax)
    final Paint facePaint = Paint()
      ..color = CompassColors.dialBackground
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      center + Offset(dxBackground, dyBackground),
      radius - 6,
      facePaint,
    );

    // 3. Draw Inner Grid Lines / Details on the Backplate
    final Paint gridPaint = Paint()
      ..color = CompassColors.tickMarkMinor.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final Offset backCenter = center + Offset(dxBackground, dyBackground);
    canvas.drawCircle(backCenter, radius * 0.5, gridPaint);
    canvas.drawCircle(backCenter, radius * 0.25, gridPaint);
    canvas.drawLine(
      Offset(backCenter.dx - radius, backCenter.dy),
      Offset(backCenter.dx + radius, backCenter.dy),
      gridPaint,
    );
    canvas.drawLine(
      Offset(backCenter.dx, backCenter.dy - radius),
      Offset(backCenter.dx, backCenter.dy + radius),
      gridPaint,
    );

    // 4. Draw the Rotating Compass Ring (Shifted moderately for mid-level parallax)
    canvas.save();
    canvas.translate(center.dx + dxMiddle, center.dy + dyMiddle);
    canvas.rotate(-headingRad); // Rotate opposing device heading

    final Paint ringPaint = Paint()
      ..color = CompassColors.tickMarkMinor.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset.zero, radius * 0.88, ringPaint);

    // Draw Ticks & Text on the Rotating Dial Ring
    final double ringRadius = radius * 0.88;
    final Paint tickPaint = Paint()..style = PaintingStyle.stroke;

    for (int i = 0; i < 360; i += 5) {
      final double angle = i * math.pi / 180 - math.pi / 2;
      final bool isMajor = i % 30 == 0;
      final bool isCardinal = i % 90 == 0;

      final double tickLength = isCardinal ? 16.0 : (isMajor ? 12.0 : 6.0);
      tickPaint.strokeWidth = isCardinal ? 2.5 : (isMajor ? 1.5 : 1.0);
      tickPaint.color = isMajor
          ? CompassColors.tickMarkMajor
          : CompassColors.tickMarkMinor;

      final Offset pStart = Offset(
        (ringRadius - tickLength) * math.cos(angle),
        (ringRadius - tickLength) * math.sin(angle),
      );
      final Offset pEnd = Offset(
        ringRadius * math.cos(angle),
        ringRadius * math.sin(angle),
      );

      canvas.drawLine(pStart, pEnd, tickPaint);

      // Print Degree Numbers for Major Marks
      if (isMajor && !isCardinal) {
        final double textAngle = angle;
        final Offset textPos = Offset(
          (ringRadius - 28) * math.cos(textAngle),
          (ringRadius - 28) * math.sin(textAngle),
        );
        _drawCenteredText(
          canvas,
          textPos,
          '$i',
          const TextStyle(
            color: CompassColors.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        );
      }
    }

    // Draw Cardinal Letters (N, E, S, W)
    const cardinals = {0: 'N', 90: 'E', 180: 'S', 270: 'W'};

    for (final entry in cardinals.entries) {
      final double angle = entry.key * math.pi / 180 - math.pi / 2;
      final String label = entry.value;
      final Offset textPos = Offset(
        (ringRadius - 26) * math.cos(angle),
        (ringRadius - 26) * math.sin(angle),
      );

      final TextStyle cardinalStyle = TextStyle(
        color: label == 'N'
            ? CompassColors.cardinalNorth
            : CompassColors.cardinalMuted,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      );

      _drawCenteredText(canvas, textPos, label, cardinalStyle);
    }

    // Draw Sub-Cardinal Letters (NE, SE, SW, NW)
    const subCardinals = {45: 'NE', 135: 'SE', 225: 'SW', 315: 'NW'};

    for (final entry in subCardinals.entries) {
      final double angle = entry.key * math.pi / 180 - math.pi / 2;
      final Offset textPos = Offset(
        (ringRadius - 26) * math.cos(angle),
        (ringRadius - 26) * math.sin(angle),
      );

      const subStyle = TextStyle(
        color: CompassColors.textMuted,
        fontSize: 12,
        fontWeight: FontWeight.bold,
      );

      _drawCenteredText(canvas, textPos, entry.value, subStyle);
    }

    canvas.restore();

    // 5. Draw Stationary Needle / Pointer (Front layer, closer to user)
    // Red indicator needle pointing North (straight UP)
    final Paint needlePaint = Paint()..style = PaintingStyle.fill;
    final Path needlePath = Path();

    // Drawing top pointer arrow
    needlePath.moveTo(center.dx, center.dy - radius * 0.9);
    needlePath.lineTo(center.dx - 10, center.dy - radius * 0.72);
    needlePath.lineTo(center.dx + 10, center.dy - radius * 0.72);
    needlePath.close();

    needlePaint.color = CompassColors.needleNorth;
    canvas.drawPath(needlePath, needlePaint);

    // Draw Lubber Line (Heading line pointing straight up)
    final Paint lubberPaint = Paint()
      ..color = CompassColors.needleNorth.withValues(alpha: 0.6)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(center.dx, center.dy - radius * 0.72),
      Offset(center.dx, center.dy + radius * 0.4),
      lubberPaint,
    );

    // Draw central glass bead pivot
    final Paint pivotPaint = Paint()
      ..color = CompassColors.dialBorder
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 12, pivotPaint);

    final Paint pivotInner = Paint()
      ..color = CompassColors.needleNorth
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 6, pivotInner);
  }

  void _drawCenteredText(
    Canvas canvas,
    Offset offset,
    String text,
    TextStyle style,
  ) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      offset - Offset(textPainter.width / 2, textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(_CompassDialPainter oldDelegate) {
    return oldDelegate.heading != heading ||
        oldDelegate.pitch != pitch ||
        oldDelegate.roll != roll;
  }
}
