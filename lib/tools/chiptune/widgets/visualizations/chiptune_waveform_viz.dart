import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import '../../chiptune_colors.dart';

/// Oscilloscope-style waveform visualizer driven by SoLoud's audio data.
class ChiptuneWaveformViz extends StatefulWidget {
  final bool active;
  const ChiptuneWaveformViz({super.key, required this.active});

  @override
  State<ChiptuneWaveformViz> createState() => _ChiptuneWaveformVizState();
}

class _ChiptuneWaveformVizState extends State<ChiptuneWaveformViz>
    with SingleTickerProviderStateMixin {
  static const int _waveSamples = 256;

  AudioData? _audioData;
  late final Ticker _ticker;
  final List<double> _samples = List<double>.filled(_waveSamples, 0);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _ensureAudioData() {
    if (_audioData != null) return;
    try {
      SoLoud.instance.setVisualizationEnabled(true);
      _audioData = AudioData(GetSamplesKind.linear);
    } catch (_) {
      _audioData = null;
    }
  }

  void _onTick(Duration _) {
    if (!widget.active) {
      _decay();
      return;
    }

    _ensureAudioData();
    final data = _audioData;
    if (data == null) return;

    try {
      data.updateSamples();
      final all = data.getAudioData(); // 256 FFT + 256 wave
      if (all.length < 512) return;
      final wave = all.sublist(256, 512);
      for (int i = 0; i < _waveSamples; i++) {
        _samples[i] = _samples[i] * 0.6 + wave[i] * 0.4;
      }
      if (mounted) setState(() {});
    } catch (_) {}
  }

  void _decay() {
    bool changed = false;
    for (int i = 0; i < _waveSamples; i++) {
      if (_samples[i].abs() > 0.005) {
        _samples[i] *= 0.9;
        changed = true;
      }
    }
    if (changed && mounted) setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    _audioData?.dispose();
    super.dispose();
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

    // Center line
    final linePaint = Paint()
      ..color = ChiptuneColors.visPeak.withValues(alpha: 0.2)
      ..strokeWidth = 0.5;
    canvas.drawLine(Offset(0, midY), Offset(size.width, midY), linePaint);
  }

  @override
  bool shouldRepaint(_WaveformPainter oldDelegate) => true;
}
