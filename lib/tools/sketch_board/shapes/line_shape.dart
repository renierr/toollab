import 'dart:ui';

import '../models/sketch_element.dart';
import 'shape_renderer.dart';

class LineShape extends ShapeRenderer {
  const LineShape();

  @override
  void paint(Canvas canvas, ShapeElement el, Paint stroke, Paint? fill) {
    canvas.drawLine(el.start.offset, el.end.offset, stroke);
  }
}
