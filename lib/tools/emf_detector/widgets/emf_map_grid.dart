import 'dart:math' as math;

import 'package:flutter/material.dart';

class EmfMapSample {
  EmfMapSample({required this.x, required this.y, required this.value});
  final int x;
  final int y;
  final double value;
}

class EmfMapGrid extends StatelessWidget {
  const EmfMapGrid({
    super.key,
    required this.cols,
    required this.rows,
    required this.samples,
    required this.threshold,
    required this.onTap,
  });

  final int cols;
  final int rows;
  final List<EmfMapSample> samples;
  final double threshold;
  final void Function(int x, int y) onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          onTapDown: (details) {
            final cw = size.width / cols;
            final ch = size.height / rows;
            final c = (details.localPosition.dx / cw).floor();
            final r = (details.localPosition.dy / ch).floor();
            if (c >= 0 && r >= 0 && c < cols && r < rows) {
              onTap(c, r);
            }
          },
          child: CustomPaint(
            size: size,
            painter: _EmfMapPainter(
              cols: cols,
              rows: rows,
              samples: samples,
              threshold: threshold,
            ),
          ),
        );
      },
    );
  }
}

class _EmfMapPainter extends CustomPainter {
  _EmfMapPainter({
    required this.cols,
    required this.rows,
    required this.samples,
    required this.threshold,
  });

  final int cols;
  final int rows;
  final List<EmfMapSample> samples;
  final double threshold;

  @override
  void paint(Canvas canvas, Size size) {
    final cw = size.width / cols;
    final ch = size.height / rows;
    final gridPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    if (samples.isNotEmpty) {
      for (int r = 0; r < rows; r++) {
        for (int c = 0; c < cols; c++) {
          final v = _interpolate(c + 0.5, r + 0.5);
          if (v == null) continue;
          final t = (v / (threshold <= 0 ? 1 : threshold)).clamp(0.0, 1.0);
          final hue = 120.0 * (1 - t);
          final color = HSVColor.fromAHSV(0.55, hue, 0.85, 0.9).toColor();
          canvas.drawRect(
            Rect.fromLTWH(c * cw, r * ch, cw, ch),
            Paint()..color = color,
          );
        }
      }
    }

    for (int c = 0; c <= cols; c++) {
      canvas.drawLine(Offset(c * cw, 0), Offset(c * cw, size.height), gridPaint);
    }
    for (int r = 0; r <= rows; r++) {
      canvas.drawLine(Offset(0, r * ch), Offset(size.width, r * ch), gridPaint);
    }

    for (final s in samples) {
      final cx = (s.x + 0.5) * cw;
      final cy = (s.y + 0.5) * ch;
      canvas.drawCircle(Offset(cx, cy), 4, Paint()..color = Colors.white);
      canvas.drawCircle(
        Offset(cx, cy),
        4,
        Paint()
          ..color = Colors.black
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  double? _interpolate(double gx, double gy) {
    if (samples.isEmpty) return null;
    double num = 0;
    double den = 0;
    for (final s in samples) {
      final dx = gx - (s.x + 0.5);
      final dy = gy - (s.y + 0.5);
      final dist = math.sqrt(dx * dx + dy * dy);
      final w = 1.0 / (dist * dist + 0.5);
      num += w * s.value;
      den += w;
    }
    if (den == 0) return null;
    return num / den;
  }

  @override
  bool shouldRepaint(covariant _EmfMapPainter old) => true;
}
