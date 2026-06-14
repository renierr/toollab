import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import '../../chiptune_colors.dart';

/// Live spectrum visualizer driven by SoLoud's FFT data.
class ChiptuneSpectrumViz extends StatefulWidget {
  final bool active;
  const ChiptuneSpectrumViz({super.key, required this.active});

  @override
  State<ChiptuneSpectrumViz> createState() => _ChiptuneSpectrumVizState();
}

class _ChiptuneSpectrumVizState extends State<ChiptuneSpectrumViz>
    with SingleTickerProviderStateMixin {
  static const int _bars = 48;
  static const int _fftBins = 256;

  AudioData? _audioData;
  late final Ticker _ticker;
  final List<double> _levels = List<double>.filled(_bars, 0);

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
      final samples = data.getAudioData();
      if (samples.length < _fftBins) return;
      for (int i = 0; i < _bars; i++) {
        final bin = (i * _fftBins / _bars).floor();
        final v = samples[bin].abs().clamp(0.0, 1.0);
        _levels[i] = v > _levels[i] ? v : _levels[i] * 0.8 + v * 0.2;
      }
      if (mounted) setState(() {});
    } catch (_) {}
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
