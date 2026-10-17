import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../wifi_heatmap_state.dart';

class WifiHeatmapGrid extends StatelessWidget {
  const WifiHeatmapGrid({
    super.key,
    required this.cols,
    required this.rows,
    required this.samples,
    required this.showHeatmap,
    required this.onTap,
  });

  final int cols;
  final int rows;
  final List<WifiSample> samples;
  final bool showHeatmap;
  final void Function(int x, int y) onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          onTapDown: (details) {
            final cell = _cellFromOffset(details.localPosition, size);
            if (cell != null) onTap(cell.$1, cell.$2);
          },
          child: CustomPaint(
            size: size,
            painter: _HeatmapPainter(
              cols: cols,
              rows: rows,
              samples: samples,
              showHeatmap: showHeatmap,
            ),
          ),
        );
      },
    );
  }

  (int, int)? _cellFromOffset(Offset pos, Size size) {
    final cw = size.width / cols;
    final ch = size.height / rows;
    final c = (pos.dx / cw).floor();
    final r = (pos.dy / ch).floor();
    if (c < 0 || r < 0 || c >= cols || r >= rows) return null;
    return (c, r);
  }
}

class _HeatmapPainter extends CustomPainter {
  _HeatmapPainter({
    required this.cols,
    required this.rows,
    required this.samples,
    required this.showHeatmap,
  });

  final int cols;
  final int rows;
  final List<WifiSample> samples;
  final bool showHeatmap;

  @override
  void paint(Canvas canvas, Size size) {
    final cw = size.width / cols;
    final ch = size.height / rows;
    final gridPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    if (showHeatmap && samples.isNotEmpty) {
      for (int r = 0; r < rows; r++) {
        for (int c = 0; c < cols; c++) {
          final rssi = _interpolate(c + 0.5, r + 0.5);
          if (rssi == null) continue;
          final color = _rssiColor(rssi);
          final rect = Rect.fromLTWH(c * cw, r * ch, cw, ch);
          canvas.drawRect(rect, Paint()..color = color);
        }
      }
    }

    // Grid lines
    for (int c = 0; c <= cols; c++) {
      canvas.drawLine(
        Offset(c * cw, 0),
        Offset(c * cw, size.height),
        gridPaint,
      );
    }
    for (int r = 0; r <= rows; r++) {
      canvas.drawLine(
        Offset(0, r * ch),
        Offset(size.width, r * ch),
        gridPaint,
      );
    }

    // Sample markers
    for (final s in samples) {
      final cx = (s.x + 0.5) * cw;
      final cy = (s.y + 0.5) * ch;
      canvas.drawCircle(
        Offset(cx, cy),
        4,
        Paint()..color = Colors.white,
      );
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
      num += w * s.rssi;
      den += w;
    }
    if (den == 0) return null;
    return num / den;
  }

  Color _rssiColor(double rssi) {
    // -30 (great) .. -90 (poor)
    final t = ((rssi + 90) / 60).clamp(0.0, 1.0);
    // hue 0 (red) -> 120 (green)
    final hue = t * 120.0;
    return HSVColor.fromAHSV(0.55, hue, 0.85, 0.9).toColor();
  }

  @override
  bool shouldRepaint(covariant _HeatmapPainter old) => true;
}
