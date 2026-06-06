import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'emf_colors.dart';

class CircularGauge extends StatelessWidget {
  final double value;
  final double maxExpected;
  final double threshold;
  final bool isScanning;
  const CircularGauge({
    super.key,
    required this.value,
    this.maxExpected = 150.0,
    required this.threshold,
    required this.isScanning,
  });

  @override
  Widget build(BuildContext context) {
    // Smooth transitions for the gauge values
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: value),
      duration: const Duration(milliseconds: 80),
      builder: (context, animatedValue, child) {
        final percentage = (animatedValue / maxExpected).clamp(0.0, 1.0);
        final isWarning = animatedValue >= threshold;

        return Stack(
          alignment: Alignment.center,
          children: [
            // Gauge Painter
            SizedBox(
              width: 250,
              height: 250,
              child: CustomPaint(
                painter: _GaugePainter(
                  percentage: percentage,
                  thresholdPercentage: threshold / maxExpected,
                  isWarning: isWarning,
                  isScanning: isScanning,
                ),
              ),
            ),
            // Central digital display
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    isScanning ? animatedValue.toStringAsFixed(1) : '---',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -1,
                      color: !isScanning
                          ? Colors.grey[600]
                          : isWarning
                          ? EmfColors.neonPink
                          : EmfColors.neonCyan,
                      shadows: isScanning
                          ? [
                              Shadow(
                                color: isWarning
                                    ? const Color(
                                        0xFFFF0055,
                                      ).withValues(alpha: 0.5)
                                    : const Color(
                                        0xFF00F2FE,
                                      ).withValues(alpha: 0.5),
                                blurRadius: 15,
                              ),
                            ]
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'MAGNETIC FIELD',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2.0,
                    color: Colors.grey[500],
                  ),
                ),
                Text(
                  'µT (microteslas)',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.0,
                    color: isScanning
                        ? (isWarning
                              ? EmfColors.neonPink.withValues(alpha: 0.7)
                              : EmfColors.neonCyan.withValues(alpha: 0.7))
                        : Colors.grey[600],
                  ),
                ),
                if (isScanning && isWarning) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: EmfColors.neonPink.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: EmfColors.neonPink.withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                    child: const Text(
                      'CABLE ALERT',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        color: EmfColors.neonPink,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        );
      },
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double percentage;
  final double thresholdPercentage;
  final bool isWarning;
  final bool isScanning;

  _GaugePainter({
    required this.percentage,
    required this.thresholdPercentage,
    required this.isWarning,
    required this.isScanning,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 12;

    // Angle conventions: 0 is right, 90 is down, 180 is left, 270 is up
    // We want the gauge to sweep from 140 degrees (bottom-left) to 400 degrees (bottom-right)
    const startAngle = 135.0 * pi / 180.0;
    const totalSweep = 270.0 * pi / 180.0;

    // 1. Draw outer glowing ambient ring
    final ambientPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.white.withValues(alpha: 0.04);
    canvas.drawCircle(center, radius + 8, ambientPaint);

    // 2. Draw background track
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10.0
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.06);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      totalSweep,
      false,
      trackPaint,
    );

    // If scanning is inactive, we just render the basic offline background
    if (!isScanning) {
      _drawTicks(canvas, center, radius, startAngle, totalSweep, 0.0);
      return;
    }

    // 3. Draw Neon Progress Arc with Gradients
    final sweepAngle = totalSweep * percentage;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Setup beautiful high-tech linear gradient
    final gradient = SweepGradient(
      center: Alignment.center,
      startAngle: startAngle,
      endAngle: startAngle + totalSweep,
      colors: const [
        EmfColors.neonCyan,
        EmfColors.neonEmerald,
        EmfColors.amberYellow,
        EmfColors.neonPink,
      ],
      stops: const [0.0, 0.35, 0.65, 1.0],
    );

    // Primary filled arc
    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10.0
      ..strokeCap = StrokeCap.round
      ..shader = gradient.createShader(rect);

    // Subtle neon outer glow for progress arc
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18.0
      ..strokeCap = StrokeCap.round
      ..shader = gradient.createShader(rect)
      ..imageFilter = ImageFilter.blur(
        sigmaX: 8.0,
        sigmaY: 8.0,
        tileMode: TileMode.decal,
      );

    if (percentage > 0) {
      canvas.drawArc(rect, startAngle, sweepAngle, false, glowPaint);
      canvas.drawArc(rect, startAngle, sweepAngle, false, progressPaint);
    }

    // 4. Draw warning threshold marker
    final thresholdAngle = startAngle + (totalSweep * thresholdPercentage);
    final thresholdPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = EmfColors.neonPink.withValues(alpha: 0.8);

    // Small radial notch for the threshold
    final tx1 = center.dx + (radius - 12) * cos(thresholdAngle);
    final ty1 = center.dy + (radius - 12) * sin(thresholdAngle);
    final tx2 = center.dx + (radius + 8) * cos(thresholdAngle);
    final ty2 = center.dy + (radius + 8) * sin(thresholdAngle);
    canvas.drawLine(Offset(tx1, ty1), Offset(tx2, ty2), thresholdPaint);

    // Draw Ticks inside the gauge
    _drawTicks(canvas, center, radius, startAngle, totalSweep, percentage);
  }

  void _drawTicks(
    Canvas canvas,
    Offset center,
    double radius,
    double startAngle,
    double totalSweep,
    double activePercentage,
  ) {
    const numTicks = 31;
    final tickPaint = Paint()..strokeWidth = 1.5;

    for (int i = 0; i < numTicks; i++) {
      final tickPercent = i / (numTicks - 1);
      final tickAngle = startAngle + (totalSweep * tickPercent);
      final isActive = isScanning && (tickPercent <= activePercentage);

      // Map color based on progress percentage
      Color tickColor;
      if (isActive) {
        if (tickPercent > thresholdPercentage) {
          tickColor = EmfColors.neonPink;
        } else if (tickPercent > 0.6) {
          tickColor = EmfColors.amberYellow;
        } else if (tickPercent > 0.3) {
          tickColor = EmfColors.neonEmerald;
        } else {
          tickColor = EmfColors.neonCyan;
        }
      } else {
        tickColor = Colors.white.withValues(alpha: 0.15);
      }

      final isMajor = i % 5 == 0;
      final tickLen = isMajor ? 10.0 : 5.0;
      tickPaint.color = tickColor;
      tickPaint.strokeWidth = isMajor ? 2.0 : 1.0;

      final innerRadius = radius - 12 - tickLen;
      final outerRadius = radius - 12;

      final x1 = center.dx + innerRadius * cos(tickAngle);
      final y1 = center.dy + innerRadius * sin(tickAngle);
      final x2 = center.dx + outerRadius * cos(tickAngle);
      final y2 = center.dy + outerRadius * sin(tickAngle);

      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.percentage != percentage ||
        oldDelegate.thresholdPercentage != thresholdPercentage ||
        oldDelegate.isWarning != isWarning ||
        oldDelegate.isScanning != isScanning;
  }
}
