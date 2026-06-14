import 'package:flutter/material.dart';

import '../../chiptune_colors.dart';
import 'chiptune_viz_data.dart';

/// 48-bar spectrum analyzer.
class ChiptuneSpectrumViz extends StatefulWidget {
  final VizData? data;
  const ChiptuneSpectrumViz({super.key, this.data});

  @override
  State<ChiptuneSpectrumViz> createState() => _ChiptuneSpectrumVizState();
}

class _ChiptuneSpectrumVizState extends State<ChiptuneSpectrumViz> {
  static const int _bars = 48;
  final List<double> _levels = List<double>.filled(_bars, 0);

  @override
  void didUpdateWidget(ChiptuneSpectrumViz oldWidget) {
    super.didUpdateWidget(oldWidget);
    final data = widget.data;
    if (data != null && oldWidget.data != data) {
      final freq = data.freq;
      for (int i = 0; i < _bars; i++) {
        final bin = (i * (freq.length - 1) / _bars).floor();
        final v = freq[bin];
        _levels[i] = v > _levels[i] ? v : _levels[i] * 0.8 + v * 0.2;
      }
    } else if (data == null) {
      _decay();
    }
  }

  void _decay() {
    bool changed = false;
    for (int i = 0; i < _bars; i++) {
      if (_levels[i] > 0) {
        _levels[i] *= 0.85;
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
        painter: _SpectrumPainter(_levels),
        size: Size.infinite,
      ),
    );
  }
}

class _SpectrumPainter extends CustomPainter {
  final List<double> levels;
  const _SpectrumPainter(this.levels);

  @override
  void paint(Canvas canvas, Size size) {
    if (levels.isEmpty) return;
    const gap = 2.0;
    final barWidth = (size.width - gap * (levels.length - 1)) / levels.length;
    if (barWidth <= 0) return;
    final paint = Paint();
    for (int i = 0; i < levels.length; i++) {
      final h = levels[i].clamp(0.0, 1.0) * size.height;
      final x = i * (barWidth + gap);
      final t = i / levels.length;
      paint.color = Color.lerp(
        ChiptuneColors.visBar,
        ChiptuneColors.visPeak,
        t,
      )!.withValues(alpha: 0.85);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, size.height - h, barWidth, h),
          const Radius.circular(1.5),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_SpectrumPainter oldDelegate) => true;
}
