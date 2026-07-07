import 'package:flutter/material.dart';

/// Horizontal loudness meter with a peak-hold tick and an optional reference
/// marker (the "marked spot" the user is comparing against).
class SfLevelMeter extends StatelessWidget {
  final double levelNorm; // 0..1
  final double peakNorm; // 0..1
  final double? referenceNorm; // 0..1
  final Color fillColor;

  const SfLevelMeter({
    super.key,
    required this.levelNorm,
    required this.peakNorm,
    required this.fillColor,
    this.referenceNorm,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 34,
      width: double.infinity,
      child: CustomPaint(
        painter: _MeterPainter(
          levelNorm: levelNorm.clamp(0.0, 1.0),
          peakNorm: peakNorm.clamp(0.0, 1.0),
          referenceNorm: referenceNorm?.clamp(0.0, 1.0),
          fillColor: fillColor,
          trackColor: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.6,
          ),
          referenceColor: theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _MeterPainter extends CustomPainter {
  final double levelNorm;
  final double peakNorm;
  final double? referenceNorm;
  final Color fillColor;
  final Color trackColor;
  final Color referenceColor;

  _MeterPainter({
    required this.levelNorm,
    required this.peakNorm,
    required this.referenceNorm,
    required this.fillColor,
    required this.trackColor,
    required this.referenceColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(size.height / 2);
    final track = RRect.fromRectAndRadius(Offset.zero & size, radius);
    canvas.drawRRect(track, Paint()..color = trackColor);

    final double fillW = (levelNorm * size.width).clamp(0.0, size.width);
    if (fillW > 0) {
      final fill = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, fillW, size.height),
        radius,
      );
      canvas.drawRRect(fill, Paint()..color = fillColor);
    }

    if (referenceNorm != null) {
      final double rx = referenceNorm! * size.width;
      final refPaint = Paint()
        ..color = referenceColor.withValues(alpha: 0.7)
        ..strokeWidth = 2;
      canvas.drawLine(Offset(rx, 2), Offset(rx, size.height - 2), refPaint);
    }

    final double px = (peakNorm * size.width).clamp(2.0, size.width - 2);
    final peakPaint = Paint()
      ..color = fillColor
      ..strokeWidth = 3;
    canvas.drawLine(Offset(px, 0), Offset(px, size.height), peakPaint);
  }

  @override
  bool shouldRepaint(_MeterPainter old) =>
      old.levelNorm != levelNorm ||
      old.peakNorm != peakNorm ||
      old.referenceNorm != referenceNorm ||
      old.fillColor != fillColor;
}
