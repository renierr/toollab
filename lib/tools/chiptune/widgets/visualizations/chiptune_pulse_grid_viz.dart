import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../chiptune_colors.dart';
import 'chiptune_viz_data.dart';

/// Pulse Grid visualizer — perspective grid with radial sparks and horizon
/// waveform. Ported from the browser-toolkit chiptune visualizer set.
class ChiptunePulseGridViz extends StatefulWidget {
  final VizData? data;
  const ChiptunePulseGridViz({super.key, this.data});

  @override
  State<ChiptunePulseGridViz> createState() => _ChiptunePulseGridVizState();
}

class _ChiptunePulseGridVizState extends State<ChiptunePulseGridViz> {
  double _gridScroll = 0;
  double _bass = 0;
  final List<double> _freq = List<double>.filled(128, 0);
  final List<double> _wave = List<double>.filled(256, 0);

  @override
  void didUpdateWidget(ChiptunePulseGridViz oldWidget) {
    super.didUpdateWidget(oldWidget);
    final data = widget.data;
    if (data != null && oldWidget.data != data) {
      final dt = data.deltaTime;
      final speed = 1 + data.bass * 5;

      for (int i = 0; i < 128; i++) {
        _freq[i] = _freq[i] * 0.7 + data.freq[i] * 0.3;
      }
      for (int i = 0; i < 256; i++) {
        _wave[i] = _wave[i] * 0.6 + data.wave[i] * 0.4;
      }
      _bass = _bass * 0.7 + data.bass * 0.3;
      _gridScroll = (_gridScroll + speed * 60 * dt) % 40;
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _PulseGridPainter(
          gridScroll: _gridScroll,
          bass: _bass,
          freq: _freq,
          wave: _wave,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _PulseGridPainter extends CustomPainter {
  final double gridScroll;
  final double bass;
  final List<double> freq;
  final List<double> wave;

  const _PulseGridPainter({
    required this.gridScroll,
    required this.bass,
    required this.freq,
    required this.wave,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;

    final horizonY = h * 0.45;
    final vanishX = w / 2;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = ChiptuneColors.visualizerBg,
    );

    final gridAlpha = (0.1 + bass * 0.3).clamp(0.0, 1.0);
    final gridPaint = Paint()
      ..color = ChiptuneColors.pulseGridCyan.withValues(alpha: gridAlpha)
      ..strokeWidth = 1;

    for (int y = 0; y < 15; y++) {
      final fy = horizonY + math.pow(y * 4 + gridScroll / 4, 2).toDouble();
      if (fy > h) continue;
      canvas.drawLine(Offset(0, fy), Offset(w, fy), gridPaint);
    }

    const lineCount = 12;
    for (int i = 0; i <= lineCount; i++) {
      final xOffset = (i / lineCount - 0.5) * w * 3;
      canvas.drawLine(
        Offset(vanishX, horizonY),
        Offset(vanishX + xOffset, h),
        gridPaint,
      );
    }

    for (int i = 0; i < 32; i++) {
      final val = freq[i * 4];
      if (val <= 0.05) continue;

      final percent = val.clamp(0.0, 1.0);
      final sizeVal = percent * 6;
      final angle = (i / 32) * math.pi - math.pi / 2;
      final dist = 50 + percent * 150;

      final px = vanishX + math.sin(angle) * dist;
      final py = horizonY - math.cos(angle) * dist * 0.5;

      final hue = 180.0 + percent * 100;
      final sparkColor = HSVColor.fromAHSV(1, hue, 1, 0.7).toColor();
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(px, py),
          width: sizeVal,
          height: sizeVal,
        ),
        Paint()..color = sparkColor,
      );
    }

    final wavePaint = Paint()
      ..color = ChiptuneColors.pulseGridMagenta.withValues(alpha: 0.8)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final wavePath = Path();
    final stepX = w / (wave.length - 1);
    for (int i = 0; i < wave.length; i++) {
      final v = wave[i].clamp(-1.0, 1.0);
      final x = i * stepX;
      final y = horizonY + v * 40 * 2;
      if (i == 0) {
        wavePath.moveTo(x, y);
      } else {
        wavePath.lineTo(x, y);
      }
    }
    canvas.drawPath(wavePath, wavePaint);

    final scanPaint = Paint()
      ..color = ChiptuneColors.pulseGridScanline.withValues(alpha: 0.1);
    for (double i = 0; i < h; i += 4) {
      canvas.drawRect(Rect.fromLTWH(0, i, w, 1), scanPaint);
    }
  }

  @override
  bool shouldRepaint(_PulseGridPainter oldDelegate) => true;
}
