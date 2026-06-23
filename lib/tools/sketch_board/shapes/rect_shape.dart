import 'dart:ui';

import '../geometry/element_bounds.dart';
import '../models/sketch_element.dart';
import 'brush.dart';
import 'shape_renderer.dart';

class RectShape extends ShapeRenderer {
  const RectShape();

  @override
  void paint(Canvas canvas, ShapeElement el, Paint stroke, Paint? fill) {
    final r = normalizeRect(el.start, el.end);
    if (r.width < 1 && r.height < 1) return;
    final pts = [r.topLeft, r.topRight, r.bottomRight, r.bottomLeft];
    if (drawBrushPath(canvas, pts, el.brushStyle, stroke, fill, closed: true)) {
      return;
    }
    if (fill != null) canvas.drawRect(r, fill);
    canvas.drawRect(r, stroke);
  }
}
