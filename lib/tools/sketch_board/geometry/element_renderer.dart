import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/sketch_element.dart';
import '../models/sketch_enums.dart';
import '../shapes/brush.dart';
import '../shapes/shape_renderer.dart';
import '../sketch_board_colors.dart';
import 'element_bounds.dart';

/// Resolves an already-decoded image for an [ImageElement.imageData] key, or
/// null if it is not ready yet.
typedef ImageResolver = ui.Image? Function(String imageData);

/// Widget-free rendering of a single element in world space. Shared by the live
/// [CustomPainter] and the PNG/thumbnail exporter. Shapes are delegated to the
/// per-type renderers in `shapes/`.
void drawElement(
  Canvas canvas,
  SketchElement el, {
  ImageResolver? imageResolver,
  bool preview = false,
}) {
  final stroke = colorFromHex(el.color);
  final fill = colorFromHexOrNull(el.fillColor);
  final alpha = preview ? 0.8 : 1.0;

  final rotation = el.rotation;
  final center = elementBounds(el).center;

  canvas.save();
  if (rotation != 0) {
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    canvas.translate(-center.dx, -center.dy);
  }

  final strokePaint = Paint()
    ..color = stroke.withValues(alpha: stroke.a * alpha)
    ..style = PaintingStyle.stroke
    ..strokeWidth = el.width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;
  final Paint? fillPaint = fill == null
      ? null
      : (Paint()
          ..color = fill.withValues(alpha: fill.a * alpha)
          ..style = PaintingStyle.fill
          ..isAntiAlias = true);

  switch (el) {
    case FreehandElement():
      _drawFreehand(canvas, el, strokePaint);
    case ShapeElement():
      shapeRenderers[el.shapeType]?.paint(canvas, el, strokePaint, fillPaint);
    case TextElement():
      _drawText(canvas, el, stroke.withValues(alpha: stroke.a * alpha));
    case ImageElement():
      _drawImage(canvas, el, imageResolver, alpha);
    case GroupElement():
      for (final sub in el.elements) {
        drawElement(
          canvas,
          sub,
          imageResolver: imageResolver,
          preview: preview,
        );
      }
    case RawElement():
      break;
  }

  canvas.restore();
}

void _drawFreehand(Canvas canvas, FreehandElement el, Paint paint) {
  final pts = el.points;
  if (pts.isEmpty) return;
  if (pts.length == 1) {
    canvas.drawCircle(
      pts.first.offset,
      math.max(0.5, el.width / 2),
      Paint()
        ..color = paint.color
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );
    return;
  }
  if (!isPlainBrush(el.brushStyle)) {
    drawBrushPath(
      canvas,
      pts.map((p) => p.offset).toList(),
      el.brushStyle,
      paint,
      null,
    );
    return;
  }
  final path = Path()..moveTo(pts.first.x, pts.first.y);
  for (int i = 1; i < pts.length - 1; i++) {
    final mid = Offset(
      (pts[i].x + pts[i + 1].x) / 2,
      (pts[i].y + pts[i + 1].y) / 2,
    );
    path.quadraticBezierTo(pts[i].x, pts[i].y, mid.dx, mid.dy);
  }
  path.lineTo(pts.last.x, pts.last.y);
  canvas.drawPath(path, paint);
}

void _drawText(Canvas canvas, TextElement el, Color color) {
  final tp = TextPainter(
    text: TextSpan(
      text: el.text,
      style: textStyleFor(el).copyWith(color: color),
    ),
    textDirection: ui.TextDirection.ltr,
  )..layout();
  tp.paint(canvas, el.position.offset);
}

void _drawImage(
  Canvas canvas,
  ImageElement el,
  ImageResolver? resolver,
  double alpha,
) {
  final img = resolver?.call(el.imageData);
  final dst = Rect.fromLTWH(
    el.position.x,
    el.position.y,
    el.imageWidth,
    el.imageHeight,
  );
  if (img == null) {
    canvas.drawRect(dst, Paint()..color = SketchBoardColors.imagePlaceholder);
    return;
  }
  final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
  canvas.drawImageRect(
    img,
    src,
    dst,
    Paint()
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.medium
      ..color = SketchBoardColors.white.withValues(alpha: alpha),
  );
}
