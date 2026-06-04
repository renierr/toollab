import 'dart:ui';
import 'package:flutter/material.dart';

class OscilloscopeChart extends StatelessWidget {
  final List<double> history;
  final double threshold;
  final double maxVal;
  final bool isScanning;

  const OscilloscopeChart({
    super.key,
    required this.history,
    required this.threshold,
    this.maxVal = 150.0,
    required this.isScanning,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 140,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF0F1019), // Deepest obsidian blue
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        child: CustomPaint(
          painter: _OscilloscopePainter(
            history: history,
            threshold: threshold,
            maxVal: maxVal,
            isScanning: isScanning,
          ),
        ),
      ),
    );
  }
}

class _OscilloscopePainter extends CustomPainter {
  final List<double> history;
  final double threshold;
  final double maxVal;
  final bool isScanning;

  _OscilloscopePainter({
    required this.history,
    required this.threshold,
    required this.maxVal,
    required this.isScanning,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.clipRect(rect);

    // 1. Draw Oscilloscope Grid (CRT Style)
    _drawGrid(canvas, size);

    if (!isScanning || history.isEmpty) {
      // Draw a flat baseline resting in the center
      final flatLinePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.1)
        ..strokeWidth = 1.5;
      canvas.drawLine(
        Offset(0, size.height - 15),
        Offset(size.width, size.height - 15),
        flatLinePaint,
      );
      return;
    }

    // 2. Draw Alert Threshold dotted line
    _drawThresholdLine(canvas, size);

    // 3. Map values to coordinates
    final points = <Offset>[];
    final double stepX = size.width / (_historyLimit() - 1);

    // Fill the chart from the right side. If history is not full, align it to the right.
    final int missingPoints = _historyLimit() - history.length;
    final double startOffset = missingPoints * stepX;

    for (int i = 0; i < history.length; i++) {
      final double x = startOffset + (i * stepX);

      // Calculate normalized height (upside-down on canvas, 0 is top, height is bottom)
      // Clamp values between 0 and maxVal for safety
      final valRatio = (history[i] / maxVal).clamp(0.0, 1.0);

      // Keep some padding at top and bottom of the chart
      final double y = size.height - 8 - (valRatio * (size.height - 16));
      points.add(Offset(x, y));
    }

    if (points.isEmpty) return;

    // 4. Construct Bézier curve path for buttery smoothness
    final path = Path();
    path.moveTo(points.first.dx, points.first.dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];

      // Control points for smooth quadratic/cubic interpolation
      final xc = (p1.dx + p2.dx) / 2;
      final yc = (p1.dy + p2.dy) / 2;
      path.quadraticBezierTo(p1.dx, p1.dy, xc, yc);
    }
    // Connect to the final point
    path.lineTo(points.last.dx, points.last.dy);

    // 5. Draw the translucent glowing area below the curve
    final areaPath = Path.from(path);
    areaPath.lineTo(points.last.dx, size.height);
    areaPath.lineTo(points.first.dx, size.height);
    areaPath.close();

    // Setup color gradients based on whether we are over threshold
    final hasWarning = history.any((val) => val >= threshold);

    final areaGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: hasWarning
          ? [
              const Color(0xFFFF0055).withValues(alpha: 0.25),
              const Color(0xFFFF0055).withValues(alpha: 0.0),
            ]
          : [
              const Color(0xFF00F2FE).withValues(alpha: 0.20),
              const Color(0xFF00F2FE).withValues(alpha: 0.0),
            ],
    );

    final areaPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = areaGradient.createShader(rect);
    canvas.drawPath(areaPath, areaPaint);

    // 6. Draw the glowing trace line
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..color = hasWarning ? const Color(0xFFFF0055) : const Color(0xFF00F2FE);

    // Add neon drop glow
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round
      ..color = (hasWarning ? const Color(0xFFFF0055) : const Color(0xFF00F2FE))
          .withValues(alpha: 0.4)
      ..imageFilter = ImageFilter.blur(sigmaX: 4.0, sigmaY: 4.0);

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, linePaint);

    // 7. Draw pulse circle on the latest reading point (the rightmost point)
    final latestPoint = points.last;
    final pulsePaint = Paint()
      ..style = PaintingStyle.fill
      ..color = hasWarning ? const Color(0xFFFF0055) : const Color(0xFF00FF87);

    final pulseOuterPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = (hasWarning ? const Color(0xFFFF0055) : const Color(0xFF00FF87))
          .withValues(alpha: 0.6);

    canvas.drawCircle(latestPoint, 4.0, pulsePaint);
    canvas.drawCircle(latestPoint, 8.0, pulseOuterPaint);
  }

  // Helper to retrieve history limit
  int _historyLimit() => 80;

  void _drawGrid(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFF00F2FE)
          .withValues(alpha: 0.03) // Very faint cyan grid lines
      ..strokeWidth = 0.8;

    // Horizontal grid lines
    const int numHorizontal = 6;
    final double hStep = size.height / numHorizontal;
    for (int i = 1; i < numHorizontal; i++) {
      final y = i * hStep;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Vertical grid lines (moving leftward)
    const int numVertical = 10;
    final double vStep = size.width / numVertical;
    for (int i = 1; i < numVertical; i++) {
      final x = i * vStep;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
  }

  void _drawThresholdLine(Canvas canvas, Size size) {
    final double threshRatio = (threshold / maxVal).clamp(0.0, 1.0);
    final double y = size.height - 8 - (threshRatio * (size.height - 16));

    final threshPaint = Paint()
      ..color = const Color(0xFFFF0055).withValues(alpha: 0.35)
      ..strokeWidth = 1.0;

    // Custom dashed line implementation
    const double dashWidth = 5.0;
    const double dashSpace = 4.0;
    double startX = 0.0;
    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, y),
        Offset(startX + dashWidth, y),
        threshPaint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _OscilloscopePainter oldDelegate) {
    return oldDelegate.history.length != history.length ||
        oldDelegate.isScanning != isScanning ||
        oldDelegate.threshold != threshold ||
        history.isNotEmpty;
  }
}
