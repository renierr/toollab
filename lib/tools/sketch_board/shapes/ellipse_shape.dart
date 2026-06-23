import 'dart:ui';

import '../geometry/element_bounds.dart';
import '../models/sketch_element.dart';
import 'shape_renderer.dart';

class EllipseShape extends ShapeRenderer {
  const EllipseShape();

  @override
  void paint(Canvas canvas, ShapeElement el, Paint stroke, Paint? fill) {
    final r = normalizeRect(el.start, el.end);
    if (r.width < 1 && r.height < 1) return;
    if (fill != null) canvas.drawOval(r, fill);
    canvas.drawOval(r, stroke);
  }
}
