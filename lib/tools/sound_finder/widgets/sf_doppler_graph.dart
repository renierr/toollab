import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../audio/doppler_analyzer.dart';

class SfDopplerGraph extends StatelessWidget {
  final List<DopplerPoint> points;
  final double duration;
  final double fApproach;
  final double fRecede;
  final double t0;
  final double distance;
  final double temperature;

  const SfDopplerGraph({
    super.key,
    required this.points,
    required this.duration,
    required this.fApproach,
    required this.fRecede,
    required this.t0,
    required this.distance,
    required this.temperature,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.15),
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.12),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        height: 240,
        padding: const EdgeInsets.all(12.0),
        child: CustomPaint(
          size: Size.infinite,
          painter: _DopplerPainter(
            points: points,
            duration: duration,
            fApproach: fApproach,
            fRecede: fRecede,
            t0: t0,
            distance: distance,
            temperature: temperature,
            pointColor: theme.colorScheme.primary,
            curveColor: theme.colorScheme.secondary,
            gridColor: theme.colorScheme.onSurfaceVariant.withValues(
              alpha: 0.15,
            ),
            textColor: theme.colorScheme.onSurfaceVariant,
            inflectionColor: theme.colorScheme.error,
          ),
        ),
      ),
    );
  }
}

class _DopplerPainter extends CustomPainter {
  final List<DopplerPoint> points;
  final double duration;
  final double fApproach;
  final double fRecede;
  final double t0;
  final double distance;
  final double temperature;

  final Color pointColor;
  final Color curveColor;
  final Color gridColor;
  final Color textColor;
  final Color inflectionColor;

  const _DopplerPainter({
    required this.points,
    required this.duration,
    required this.fApproach,
    required this.fRecede,
    required this.t0,
    required this.distance,
    required this.temperature,
    required this.pointColor,
    required this.curveColor,
    required this.gridColor,
    required this.textColor,
    required this.inflectionColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double maxTime = duration > 0 ? duration : 5.0;

    // Determine Y range. We want the graph to center nicely.
    double minF = math.min(fApproach, fRecede);
    double maxF = math.max(fApproach, fRecede);

    if (points.isNotEmpty) {
      for (final p in points) {
        if (p.frequency < minF) minF = p.frequency;
        if (p.frequency > maxF) maxF = p.frequency;
      }
    }

    // Add padding to Y range
    double rangePadding = (maxF - minF) * 0.15;
    if (rangePadding < 50.0) rangePadding = 50.0;
    final double plotMinF = math.max(20.0, minF - rangePadding);
    final double plotMaxF = maxF + rangePadding;

    final double width = size.width;
    final double height = size.height;

    // Helper functions to map coordinates
    double mapX(double t) => (t / maxTime) * width;
    double mapY(double f) {
      final double norm = (f - plotMinF) / (plotMaxF - plotMinF);
      return height - (norm * height);
    }

    // Draw Grid Lines & Labels
    final Paint gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    void drawText(String text, double x, double y, Alignment alignment) {
      textPainter.text = TextSpan(
        text: text,
        style: TextStyle(color: textColor, fontSize: 10),
      );
      textPainter.layout();
      final double tx = x - (alignment.x + 1.0) * 0.5 * textPainter.width;
      final double ty = y - (alignment.y + 1.0) * 0.5 * textPainter.height;
      textPainter.paint(canvas, Offset(tx, ty));
    }

    // Horizontal grid (frequency)
    const int freqDivisions = 4;
    for (int i = 0; i <= freqDivisions; i++) {
      final double f = plotMinF + (plotMaxF - plotMinF) * (i / freqDivisions);
      final double y = mapY(f);
      canvas.drawLine(Offset(0, y), Offset(width, y), gridPaint);
      drawText('${f.toStringAsFixed(0)} Hz', 4, y - 2, Alignment.centerLeft);
    }

    // Vertical grid (time)
    const int timeDivisions = 5;
    for (int i = 1; i < timeDivisions; i++) {
      final double t = maxTime * (i / timeDivisions);
      final double x = mapX(t);
      canvas.drawLine(Offset(x, 0), Offset(x, height), gridPaint);
      drawText(
        '${t.toStringAsFixed(1)}s',
        x,
        height - 12,
        Alignment.bottomCenter,
      );
    }

    // Draw experimental points
    if (points.isNotEmpty) {
      final Paint ptPaint = Paint()
        ..color = pointColor.withValues(alpha: 0.6)
        ..style = PaintingStyle.fill;

      for (final p in points) {
        if (p.time <= maxTime &&
            p.frequency >= plotMinF &&
            p.frequency <= plotMaxF) {
          canvas.drawCircle(
            Offset(mapX(p.time), mapY(p.frequency)),
            2.0,
            ptPaint,
          );
        }
      }
    }

    // Calculate Doppler model parameters
    final double c = 331.3 + 0.606 * temperature;
    final double denom = fApproach + fRecede;
    final double f0 = denom > 0 ? (2.0 * fApproach * fRecede) / denom : 0.0;
    final double v = denom > 0 ? c * (fApproach - fRecede) / denom : 0.0;

    // Draw theoretical curve
    if (f0 > 0) {
      final Paint curvePaint = Paint()
        ..color = curveColor
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final Path path = Path();
      bool first = true;

      // Draw 100 steps across the width
      for (int i = 0; i <= 100; i++) {
        final double t = maxTime * (i / 100);
        final double distOffset = v * (t - t0);
        final double denomTerm = math.sqrt(
          distance * distance + distOffset * distOffset,
        );
        final double cosTheta = denomTerm > 0 ? distOffset / denomTerm : 0.0;
        final double dopplerFactor = 1.0 - (v / c) * cosTheta;
        final double f = dopplerFactor > 0 ? f0 / dopplerFactor : 0.0;

        final double x = mapX(t);
        final double y = mapY(f);

        if (y >= 0 && y <= height) {
          if (first) {
            path.moveTo(x, y);
            first = false;
          } else {
            path.lineTo(x, y);
          }
        }
      }
      canvas.drawPath(path, curvePaint);
    }

    // Mark important points: fApproach line, fRecede line, and Inflection point t0
    final Paint markerPaint = Paint()
      ..color = inflectionColor.withValues(alpha: 0.7)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Draw vertical inflection line t0
    final double t0X = mapX(t0);
    if (t0X >= 0 && t0X <= width) {
      // Dash-like vertical line
      double y = 0;
      while (y < height) {
        canvas.drawLine(
          Offset(t0X, y),
          Offset(t0X, math.min(y + 6, height)),
          markerPaint,
        );
        y += 12;
      }
      drawText('t₀', t0X + 8, 12, Alignment.topLeft);
    }

    // Draw approach/recede level markers on the sides
    final Paint levelPaint = Paint()
      ..color = curveColor.withValues(alpha: 0.5)
      ..strokeWidth = 1.0;
    canvas.drawLine(
      Offset(0, mapY(fApproach)),
      Offset(width, mapY(fApproach)),
      levelPaint,
    );
    canvas.drawLine(
      Offset(0, mapY(fRecede)),
      Offset(width, mapY(fRecede)),
      levelPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _DopplerPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.duration != duration ||
        oldDelegate.fApproach != fApproach ||
        oldDelegate.fRecede != fRecede ||
        oldDelegate.t0 != t0 ||
        oldDelegate.distance != distance ||
        oldDelegate.temperature != temperature ||
        oldDelegate.pointColor != pointColor ||
        oldDelegate.curveColor != curveColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.textColor != textColor ||
        oldDelegate.inflectionColor != inflectionColor;
  }
}
