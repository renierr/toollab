import 'dart:ui';

import '../models/sketch_element.dart';
import 'arrow_shape.dart';
import 'checkmark_shape.dart';
import 'diamond_shape.dart';
import 'ellipse_shape.dart';
import 'hexagon_shape.dart';
import 'line_shape.dart';
import 'rect_shape.dart';
import 'speech_bubble_shape.dart';
import 'triangle_shape.dart';

/// Renders one start/end based shape. One implementation per shape type lives in
/// its own file, mirroring the reference project's `shapes/` tool registry.
abstract class ShapeRenderer {
  const ShapeRenderer();

  /// [stroke] is preconfigured; [fill] is null when the shape has no fill.
  void paint(Canvas canvas, ShapeElement el, Paint stroke, Paint? fill);
}

void fillThenStroke(Canvas canvas, Path path, Paint stroke, Paint? fill) {
  if (fill != null) canvas.drawPath(path, fill);
  canvas.drawPath(path, stroke);
}

const Map<String, ShapeRenderer> shapeRenderers = {
  'line': LineShape(),
  'rect': RectShape(),
  'ellipse': EllipseShape(),
  'triangle': TriangleShape(),
  'diamond': DiamondShape(),
  'hexagon': HexagonShape(),
  'arrow': ArrowShape(),
  'double-arrow': DoubleArrowShape(),
  'speech-bubble': SpeechBubbleShape(),
  'checkmark': CheckmarkShape(),
};
