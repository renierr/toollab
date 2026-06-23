import 'dart:ui';

import '../geometry/element_bounds.dart';
import '../models/sketch_element.dart';
import 'brush.dart';
import 'shape_renderer.dart';

class HexagonShape extends ShapeRenderer {
  const HexagonShape();

  @override
  void paint(Canvas canvas, ShapeElement el, Paint stroke, Paint? fill) {
    final r = normalizeRect(el.start, el.end);
    if (r.width < 1 || r.height < 1) return;
    final x = r.left, y = r.top, w = r.width, h = r.height;
    final pts = [
      Offset(x + w * 0.25, y),
      Offset(x + w * 0.75, y),
      Offset(x + w, y + h * 0.5),
      Offset(x + w * 0.75, y + h),
      Offset(x + w * 0.25, y + h),
      Offset(x, y + h * 0.5),
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
