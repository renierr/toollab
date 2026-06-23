import 'dart:ui';

import '../models/sketch_element.dart';
import 'brush.dart';
import 'shape_renderer.dart';

class LineShape extends ShapeRenderer {
  const LineShape();

  @override
  void paint(Canvas canvas, ShapeElement el, Paint stroke, Paint? fill) {
    final pts = [el.start.offset, el.end.offset];
    if (drawBrushPath(canvas, pts, el.brushStyle, stroke, null)) return;
    canvas.drawLine(el.start.offset, el.end.offset, stroke);
  }
}
