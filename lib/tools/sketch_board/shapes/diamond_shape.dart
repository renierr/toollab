import 'dart:ui';

import '../geometry/element_bounds.dart';
import '../models/sketch_element.dart';
import 'brush.dart';
import 'shape_renderer.dart';

class DiamondShape extends ShapeRenderer {
  const DiamondShape();

  @override
  void paint(Canvas canvas, ShapeElement el, Paint stroke, Paint? fill) {
    final r = normalizeRect(el.start, el.end);
    if (r.width < 1 || r.height < 1) return;
    final pts = [
      Offset(r.left + r.width / 2, r.top),
      Offset(r.right, r.top + r.height / 2),
      Offset(r.left + r.width / 2, r.bottom),
      Offset(r.left, r.top + r.height / 2),
    ];
    if (drawBrushPath(canvas, pts, el.brushStyle, stroke, fill, closed: true)) {
      return;
    }
    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    path.close();
    fillThenStroke(canvas, path, stroke, fill);
  }
}
