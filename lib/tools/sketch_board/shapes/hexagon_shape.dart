import 'dart:ui';

import '../geometry/element_bounds.dart';
import '../models/sketch_element.dart';
import 'shape_renderer.dart';

class HexagonShape extends ShapeRenderer {
  const HexagonShape();

  @override
  void paint(Canvas canvas, ShapeElement el, Paint stroke, Paint? fill) {
    final r = normalizeRect(el.start, el.end);
    if (r.width < 1 || r.height < 1) return;
    final x = r.left, y = r.top, w = r.width, h = r.height;
    final path = Path()
      ..moveTo(x + w * 0.25, y)
      ..lineTo(x + w * 0.75, y)
      ..lineTo(x + w, y + h * 0.5)
      ..lineTo(x + w * 0.75, y + h)
      ..lineTo(x + w * 0.25, y + h)
      ..lineTo(x, y + h * 0.5)
      ..close();
    fillThenStroke(canvas, path, stroke, fill);
  }
}
