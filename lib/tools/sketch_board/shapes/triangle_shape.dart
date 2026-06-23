import 'dart:ui';

import '../geometry/element_bounds.dart';
import '../models/sketch_element.dart';
import 'brush.dart';
import 'shape_renderer.dart';

class TriangleShape extends ShapeRenderer {
  const TriangleShape();

  @override
  void paint(Canvas canvas, ShapeElement el, Paint stroke, Paint? fill) {
    final r = normalizeRect(el.start, el.end);
    if (r.width < 1 || r.height < 1) return;
    final pts = [
      Offset(r.left + r.width / 2, r.top),
      Offset(r.right, r.bottom),
      Offset(r.left, r.bottom),
    ];
    if (drawBrushPath(canvas, pts, el.brushStyle, stroke, fill, closed: true)) {
      return;
    }
    final path = Path()
      ..moveTo(pts[0].dx, pts[0].dy)
      ..lineTo(pts[1].dx, pts[1].dy)
      ..lineTo(pts[2].dx, pts[2].dy)
      ..close();
    fillThenStroke(canvas, path, stroke, fill);
  }
}
