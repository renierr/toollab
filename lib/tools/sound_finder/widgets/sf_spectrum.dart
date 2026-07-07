import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../sound_finder_colors.dart';

/// Log-scaled spectrum bar display with a marker at the dominant frequency.
class SfSpectrum extends StatelessWidget {
  final Float64List bars;
  final double peakFreqHz;
  static const double minHz = 20;
  static const double maxHz = 22050;

  const SfSpectrum({super.key, required this.bars, required this.peakFreqHz});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 96,
        width: double.infinity,
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        child: CustomPaint(
          painter: _SpectrumPainter(
            bars: bars,
            peakFreqHz: peakFreqHz,
            markerColor: theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _SpectrumPainter extends CustomPainter {
  final Float64List bars;
  final double peakFreqHz;
  final Color markerColor;

  _SpectrumPainter({
    required this.bars,
    required this.peakFreqHz,
    required this.markerColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty) return;
    final double gap = 2;
    final double barWidth =
        (size.width - gap * (bars.length - 1)) / bars.length;

    for (int i = 0; i < bars.length; i++) {
      final double h = (bars[i] * size.height).clamp(1.0, size.height);
      final double x = i * (barWidth + gap);
      final Color color = Color.lerp(
        SoundFinderColors.spectrumLow,
        SoundFinderColors.spectrumHigh,
        i / bars.length,
      )!;
      final paint = Paint()
        ..color = color.withValues(alpha: 0.35 + 0.65 * bars[i]);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, size.height - h, barWidth, h),
          const Radius.circular(2),
        ),
        paint,
      );
    }

    if (peakFreqHz > SfSpectrum.minHz) {
      final double logMin = math.log(SfSpectrum.minHz);
      final double logMax = math.log(SfSpectrum.maxHz);
      final double t = ((math.log(peakFreqHz) - logMin) / (logMax - logMin))
          .clamp(0.0, 1.0);
      final double mx = t * size.width;
      final markerPaint = Paint()
        ..color = markerColor.withValues(alpha: 0.55)
        ..strokeWidth = 1.5;
      canvas.drawLine(Offset(mx, 0), Offset(mx, size.height), markerPaint);
    }
  }

  @override
  bool shouldRepaint(_SpectrumPainter old) =>
      old.peakFreqHz != peakFreqHz || !identical(old.bars, bars);
}
