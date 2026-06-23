import 'dart:ui';

import '../geometry/element_bounds.dart';
import '../models/sketch_element.dart';
import 'shape_renderer.dart';

class CheckmarkShape extends ShapeRenderer {
  const CheckmarkShape();

  @override
  void paint(Canvas canvas, ShapeElement el, Paint stroke, Paint? fill) {
    final r = normalizeRect(el.start, el.end);
    if (r.width < 1 || r.height < 1) return;
    final x = r.left, y = r.top, w = r.width, h = r.height;
    canvas.drawPath(
      Path()
        ..moveTo(x + w * 0.1, y + h * 0.55)
        ..lineTo(x + w * 0.35, y + h * 0.95)
        ..lineTo(x + w * 0.9, y + h * 0.1),
      stroke,
    );
  }
}
