import 'dart:ui';

import '../geometry/element_bounds.dart';
import '../models/sketch_element.dart';
import 'brush.dart';
import 'shape_renderer.dart';

class CheckmarkShape extends ShapeRenderer {
  const CheckmarkShape();

  @override
  void paint(Canvas canvas, ShapeElement el, Paint stroke, Paint? fill) {
    final r = normalizeRect(el.start, el.end);
    if (r.width < 1 || r.height < 1) return;
    final x = r.left, y = r.top, w = r.width, h = r.height;
    final pts = [
      Offset(x + w * 0.1, y + h * 0.55),
      Offset(x + w * 0.35, y + h * 0.95),
      Offset(x + w * 0.9, y + h * 0.1),
    ];
    if (drawBrushPath(canvas, pts, el.brushStyle, stroke, null)) return;
    canvas.drawPath(
      Path()
        ..moveTo(pts[0].dx, pts[0].dy)
        ..lineTo(pts[1].dx, pts[1].dy)
        ..lineTo(pts[2].dx, pts[2].dy),
      stroke,
    );
  }
}
