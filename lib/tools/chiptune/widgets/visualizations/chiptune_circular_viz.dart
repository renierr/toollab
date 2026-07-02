import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../chiptune_colors.dart';
import 'chiptune_viz_data.dart';

class ChiptuneCircularViz extends StatefulWidget {
  final VizData? data;
  const ChiptuneCircularViz({super.key, this.data});

  @override
  State<ChiptuneCircularViz> createState() => _ChiptuneCircularVizState();
}

class _ChiptuneCircularVizState extends State<ChiptuneCircularViz> {
  static const int _bars = 64;
  final List<double> _levels = List.filled(_bars, 0.0);
  double _rotation = 0;

  @override
  void didUpdateWidget(ChiptuneCircularViz oldWidget) {
    super.didUpdateWidget(oldWidget);
    final data = widget.data;
    if (data != null && oldWidget.data != data) {
      final freq = data.freq;
      for (int i = 0; i < _bars; i++) {
        final bin = (i * (freq.length - 1) / _bars).floor();
        final v = freq[bin];
        _levels[i] = v > _levels[i] ? v : _levels[i] * 0.85 + v * 0.15;
      }
      _rotation = (_rotation + data.deltaTime * 30) % 360;
    } else if (data == null) {
      _decay();
    }
  }

  void _decay() {
    bool changed = false;
    for (int i = 0; i < _bars; i++) {
      if (_levels[i] > 0) {
        _levels[i] *= 0.9;
        if (_levels[i] < 0.01) _levels[i] = 0;
        changed = true;
      }
    }
    if (changed) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _CircularPainter(
          levels: _levels,
          rotation: _rotation,
          bass: widget.data?.bass ?? 0,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _CircularPainter extends CustomPainter {
  final List<double> levels;
  final double rotation;
  final double bass;

  const _CircularPainter({
    required this.levels,
    required this.rotation,
    required this.bass,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = ChiptuneColors.visualizerBg,
    );

    final cx = w / 2;
    final cy = h / 2;
    final maxR = math.min(w, h) * 0.42;
    final innerR = maxR * 0.2;
    final rotRad = rotation * math.pi / 180;

    for (int i = 0; i < levels.length; i++) {
      final val = levels[i];
      if (val <= 0.005) continue;

      final barH = val * (maxR - innerR);
      final angle = (i / levels.length) * math.pi * 2 + rotRad;
      final hue = (i / levels.length) * 360;

      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(angle);

      final bw = ((math.pi * 2 / levels.length) * maxR * 0.5).clamp(1.0, 6.0);

      final barRect = Rect.fromLTWH(-bw / 2, innerR, bw, barH);

      final color = HSVColor.fromAHSV(0.85, hue, 1, 0.8).toColor();
      final paint = Paint()
        ..color = color
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      canvas.drawRRect(
        RRect.fromRectAndRadius(barRect, Radius.circular(bw / 2)),
        paint,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(-bw / 4, innerR, bw / 2, barH),
          Radius.circular(bw / 4),
        ),
        Paint()..color = HSVColor.fromAHSV(0.85, hue, 0.2, 1).toColor(),
      );

      canvas.restore();
    }

    final bassPulse = 0.3 + bass * 0.7;
    canvas.drawCircle(
      Offset(cx, cy),
      innerR * bassPulse,
      Paint()
        ..color = HSVColor.fromAHSV(
          0.4 + bass * 0.3,
          200 + bass * 40,
          1,
          1,
        ).toColor()
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    canvas.drawCircle(
      Offset(cx, cy),
      innerR * 0.5 * bassPulse,
      Paint()..color = HSVColor.fromAHSV(1, 200 + bass * 40, 0.1, 1).toColor(),
    );
  }

  @override
  bool shouldRepaint(_CircularPainter oldDelegate) => true;
}
