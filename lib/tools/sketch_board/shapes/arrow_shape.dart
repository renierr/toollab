import 'dart:math' as math;
import 'dart:ui';

import '../models/sketch_element.dart';
import 'shape_renderer.dart';

class ArrowShape extends ShapeRenderer {
  const ArrowShape();

  @override
  void paint(Canvas canvas, ShapeElement el, Paint stroke, Paint? fill) {
    paintArrow(
      canvas,
      el.start.offset,
      el.end.offset,
      el.width,
      stroke,
      startHead: false,
    );
  }
}

class DoubleArrowShape extends ShapeRenderer {
  const DoubleArrowShape();

  @override
  void paint(Canvas canvas, ShapeElement el, Paint stroke, Paint? fill) {
    paintArrow(
      canvas,
      el.start.offset,
      el.end.offset,
      el.width,
      stroke,
      startHead: true,
    );
  }
}

void paintArrow(
  Canvas canvas,
  Offset start,
  Offset end,
  double strokeW,
  Paint stroke, {
  required bool startHead,
}) {
  final dx = end.dx - start.dx;
  final dy = end.dy - start.dy;
  final len = math.sqrt(dx * dx + dy * dy);
  if (len < 1) return;

  final angle = math.atan2(dy, dx);
  final headLen = math.min(len * 0.3, math.max(strokeW * 3, 10.0));
  final spread = math.pi / 6;
  final halfBase = math.max(strokeW * 1.5, headLen * math.sin(spread));
  final perp = Offset(-math.sin(angle), math.cos(angle));
  final dir = Offset(math.cos(angle), math.sin(angle));

  final shaftStart = startHead ? start + dir * headLen : start;
  final shaftEnd = end - dir * headLen;
  canvas.drawLine(shaftStart, shaftEnd, stroke);

  final head = Paint()
    ..color = stroke.color
    ..style = PaintingStyle.fill
    ..isAntiAlias = true;

  final endBase = end - dir * headLen;
  canvas.drawPath(
    Path()
      ..moveTo(end.dx, end.dy)
      ..lineTo(endBase.dx + perp.dx * halfBase, endBase.dy + perp.dy * halfBase)
      ..lineTo(endBase.dx - perp.dx * halfBase, endBase.dy - perp.dy * halfBase)
      ..close(),
    head,
  );

  if (startHead) {
    final startBase = start + dir * headLen;
    canvas.drawPath(
      Path()
        ..moveTo(start.dx, start.dy)
        ..lineTo(
          startBase.dx + perp.dx * halfBase,
          startBase.dy + perp.dy * halfBase,
        )
        ..lineTo(
          startBase.dx - perp.dx * halfBase,
          startBase.dy - perp.dy * halfBase,
        )
        ..close(),
      head,
    );
  }
}
