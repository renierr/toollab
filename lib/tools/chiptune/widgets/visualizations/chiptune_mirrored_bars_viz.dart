import 'package:flutter/material.dart';

import '../../chiptune_colors.dart';
import 'chiptune_viz_data.dart';

class ChiptuneMirroredBarsViz extends StatefulWidget {
  final VizData? data;
  const ChiptuneMirroredBarsViz({super.key, this.data});

  @override
  State<ChiptuneMirroredBarsViz> createState() =>
      _ChiptuneMirroredBarsVizState();
}

class _ChiptuneMirroredBarsVizState extends State<ChiptuneMirroredBarsViz> {
  static const int _bars = 48;
  final List<double> _levels = List.filled(_bars, 0.0);
  final List<double> _peaks = List.filled(_bars, 0.0);

  @override
  void didUpdateWidget(ChiptuneMirroredBarsViz oldWidget) {
    super.didUpdateWidget(oldWidget);
    final data = widget.data;
    if (data != null && oldWidget.data != data) {
      final freq = data.freq;
      for (int i = 0; i < _bars; i++) {
        final bin = (i * (freq.length - 1) / _bars).floor();
        final v = freq[bin];
        _levels[i] = v > _levels[i] ? v : _levels[i] * 0.85 + v * 0.15;
        if (v >= _peaks[i]) {
          _peaks[i] = v;
        } else {
          _peaks[i] -= 0.02;
          if (_peaks[i] < 0) _peaks[i] = 0;
        }
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
      if (_peaks[i] > 0) {
        _peaks[i] -= 0.03;
        if (_peaks[i] < 0) _peaks[i] = 0;
        changed = true;
      }
    }
    if (changed) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _MirroredBarsPainter(
          levels: _levels,
          peaks: _peaks,
          bass: widget.data?.bass ?? 0,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _MirroredBarsPainter extends CustomPainter {
  final List<double> levels;
  final List<double> peaks;
  final double bass;

  const _MirroredBarsPainter({
    required this.levels,
    required this.peaks,
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

    final midY = h / 2;
    const gap = 2.0;
    final barWidth = (w - gap * (levels.length - 1)) / levels.length;
    if (barWidth <= 0) return;

    for (int i = 0; i < levels.length; i++) {
      final val = levels[i].clamp(0.0, 1.0);
      if (val <= 0.005) continue;

      final barH = val * midY * 0.85;
      final x = i * (barWidth + gap);
      final t = i / levels.length;

      final glowColor = Color.lerp(
        ChiptuneColors.visBar,
        ChiptuneColors.visPeak,
        t,
      )!;

      final glowPaint = Paint()
        ..color = glowColor.withValues(alpha: 0.2 + bass * 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, midY - barH, barWidth, barH * 2),
          Radius.circular(barWidth / 2),
        ),
        glowPaint,
      );

      final barPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(
              ChiptuneColors.visBar,
              ChiptuneColors.visPeak,
              t,
            )!.withValues(alpha: 0.9),
            Color.lerp(
              ChiptuneColors.visBar,
              ChiptuneColors.visPeak,
              t,
            )!.withValues(alpha: 0.5),
          ],
        ).createShader(Rect.fromLTWH(x, midY - barH, barWidth, barH * 2));

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, midY - barH, barWidth, barH * 2),
          Radius.circular(barWidth / 2),
        ),
        barPaint,
      );

      final peakVal = peaks[i].clamp(0.0, 1.0);
      if (peakVal > 0.01) {
        final peakY = midY - peakVal * midY * 0.85;
        final peakPaint = Paint()
          ..color = Color.lerp(
            ChiptuneColors.visPeak,
            Colors.white,
            peakVal,
          )!.withValues(alpha: 0.9);
        canvas.drawRect(Rect.fromLTWH(x, peakY - 1.5, barWidth, 3), peakPaint);

        canvas.drawRect(
          Rect.fromLTWH(x, peakY - 1.5, barWidth, 3),
          Paint()
            ..color = peakPaint.color.withValues(alpha: 0.3)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        );

        canvas.drawRect(
          Rect.fromLTWH(x, midY + peakVal * midY * 0.85 - 1.5, barWidth, 3),
          peakPaint,
        );

        canvas.drawRect(
          Rect.fromLTWH(x, midY + peakVal * midY * 0.85 - 1.5, barWidth, 3),
          Paint()
            ..color = peakPaint.color.withValues(alpha: 0.3)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        );
      }
    }

    canvas.drawLine(
      Offset(0, midY),
      Offset(w, midY),
      Paint()
        ..color = ChiptuneColors.visPeak.withValues(alpha: 0.15 + bass * 0.1)
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_MirroredBarsPainter oldDelegate) => true;
}
