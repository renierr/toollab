import 'package:flutter/material.dart';

import '../../chiptune_colors.dart';
import 'chiptune_viz_data.dart';

/// Oscilloscope-style waveform visualizer.
class ChiptuneWaveformViz extends StatefulWidget {
  final VizData? data;
  const ChiptuneWaveformViz({super.key, this.data});

  @override
  State<ChiptuneWaveformViz> createState() => _ChiptuneWaveformVizState();
}

class _ChiptuneWaveformVizState extends State<ChiptuneWaveformViz> {
  static const int _waveSamples = 256;
  final List<double> _samples = List<double>.filled(_waveSamples, 0);

  @override
  void didUpdateWidget(ChiptuneWaveformViz oldWidget) {
    super.didUpdateWidget(oldWidget);
    final data = widget.data;
    if (data != null && oldWidget.data != data) {
      final wave = data.wave;
      for (int i = 0; i < _waveSamples; i++) {
        _samples[i] = _samples[i] * 0.6 + wave[i] * 0.4;
      }
    } else if (data == null) {
      _decay();
    }
  }

  void _decay() {
    bool changed = false;
    for (int i = 0; i < _waveSamples; i++) {
      if (_samples[i].abs() > 0.005) {
        _samples[i] *= 0.9;
        changed = true;
      }
    }
    if (changed) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _WaveformPainter(_samples),
        size: Size.infinite,
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final List<double> samples;
  const _WaveformPainter(this.samples);

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.isEmpty) return;

    final midY = size.height / 2;
    final paint = Paint()
      ..color = ChiptuneColors.visBar
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path();
    final stepX = size.width / (samples.length - 1);

    path.moveTo(0, midY + samples[0] * midY * 0.9);
    for (int i = 1; i < samples.length; i++) {
      final x = i * stepX;
      final y = midY + samples[i] * midY * 0.9;
      path.lineTo(x, y);
    }

    canvas.drawPath(path, paint);

    final linePaint = Paint()
      ..color = ChiptuneColors.visPeak.withValues(alpha: 0.2)
      ..strokeWidth = 0.5;
    canvas.drawLine(Offset(0, midY), Offset(size.width, midY), linePaint);
  }

  @override
  bool shouldRepaint(_WaveformPainter oldDelegate) => true;
}
