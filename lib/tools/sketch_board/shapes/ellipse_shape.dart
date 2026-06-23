import 'dart:math' as math;
import 'dart:ui';

import '../geometry/element_bounds.dart';
import '../models/sketch_element.dart';
import 'brush.dart';
import 'shape_renderer.dart';

class EllipseShape extends ShapeRenderer {
  const EllipseShape();

  @override
  void paint(Canvas canvas, ShapeElement el, Paint stroke, Paint? fill) {
    final r = normalizeRect(el.start, el.end);
    if (r.width < 1 && r.height < 1) return;
    if (!isPlainBrush(el.brushStyle)) {
      final rx = r.width / 2, ry = r.height / 2;
      final segments = math.max(12, (math.max(rx, ry) / 5).floor());
      final pts = [
        for (int i = 0; i < segments; i++)
          Offset(
            r.center.dx + math.cos(i / segments * 2 * math.pi) * rx,
            r.center.dy + math.sin(i / segments * 2 * math.pi) * ry,
          ),
      ];
      drawBrushPath(canvas, pts, el.brushStyle, stroke, fill, closed: true);
      return;
    }
    if (fill != null) canvas.drawOval(r, fill);
    canvas.drawOval(r, stroke);
  }
}
