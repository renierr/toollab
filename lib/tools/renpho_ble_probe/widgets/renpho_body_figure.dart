import 'package:flutter/material.dart';

import '../renpho_body_geometry.dart';
import '../renpho_body_metrics.dart';

/// The front-view figure with a leader line running from every limb to its
/// callout. Sizes itself to whatever the surrounding stack offers.
class RenphoBodyFigure extends StatelessWidget {
  final List<RenphoSegmentValues> segments;
  final RenphoSegment active;

  const RenphoBodyFigure({
    super.key,
    required this.segments,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CustomPaint(
      size: Size.infinite,
      painter: _BodyPainter(
        segments: segments,
        active: active,
        neutral: theme.colorScheme.onSurface.withValues(alpha: 0.12),
        outline: theme.colorScheme.onSurface.withValues(alpha: 0.22),
      ),
    );
  }
}

class _BodyPainter extends CustomPainter {
  final List<RenphoSegmentValues> segments;
  final RenphoSegment active;
  final Color neutral;
  final Color outline;

  _BodyPainter({
    required this.segments,
    required this.active,
    required this.neutral,
    required this.outline,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final figure = RenphoBodyGeometry.figureRect(size);
    canvas.drawPath(
      RenphoBodyGeometry.headAndNeck(figure),
      Paint()..color = neutral,
    );

    // The trunk goes down first so the arms join it at the shoulder.
    final ordered = [
      ...segments.where((values) => values.segment == RenphoSegment.trunk),
      ...segments.where((values) => values.segment != RenphoSegment.trunk),
    ];
    for (final values in ordered) {
      final segment = values.segment;
      final selected = segment == active;
      final color = RenphoBodyGeometry.tint(values.muscleOfStandardPercent);
      final path = RenphoBodyGeometry.path(segment, figure);

      if (selected) {
        canvas.drawPath(
          path,
          Paint()
            ..color = color.withValues(alpha: 0.5)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
        );
      }
      canvas.drawPath(
        path,
        Paint()..color = color.withValues(alpha: selected ? 0.55 : 0.22),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = selected ? 2 : 1
          ..color = selected ? color : outline,
      );

      _drawLeader(canvas, size, figure, segment, color, selected);
    }
  }

  void _drawLeader(
    Canvas canvas,
    Size size,
    Rect figure,
    RenphoSegment segment,
    Color color,
    bool selected,
  ) {
    final anchor = RenphoBodyGeometry.anchor(segment, figure);
    final end = segment == RenphoSegment.trunk
        ? Offset(size.width / 2 - 24, RenphoBodyGeometry.topBand - 8)
        : Offset(
            RenphoBodyGeometry.onLeftSide(segment)
                ? figure.left - 6
                : figure.right + 6,
            RenphoBodyGeometry.calloutCenterY(segment, figure),
          );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color.withValues(alpha: selected ? 0.9 : 0.35);
    canvas.drawLine(anchor, end, paint);
    canvas.drawCircle(
      anchor,
      selected ? 3.5 : 2.5,
      Paint()..color = color.withValues(alpha: selected ? 1 : 0.5),
    );
  }

  @override
  bool shouldRepaint(_BodyPainter old) =>
      old.active != active ||
      old.segments != segments ||
      old.neutral != neutral;
}
