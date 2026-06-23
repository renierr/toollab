import 'dart:ui';

import '../geometry/element_bounds.dart';
import '../models/sketch_element.dart';
import 'shape_renderer.dart';

class DiamondShape extends ShapeRenderer {
  const DiamondShape();

  @override
  void paint(Canvas canvas, ShapeElement el, Paint stroke, Paint? fill) {
    final r = normalizeRect(el.start, el.end);
    if (r.width < 1 || r.height < 1) return;
    final path = Path()
      ..moveTo(r.left + r.width / 2, r.top)
      ..lineTo(r.right, r.top + r.height / 2)
      ..lineTo(r.left + r.width / 2, r.bottom)
      ..lineTo(r.left, r.top + r.height / 2)
      ..close();
    fillThenStroke(canvas, path, stroke, fill);
  }
}
