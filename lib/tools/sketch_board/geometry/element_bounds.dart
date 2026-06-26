import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/sketch_element.dart';
import '../sketch_board_colors.dart';

/// Axis-aligned rectangle from two corner points (any winding order).
Rect normalizeRect(SkPoint a, SkPoint b) {
  final x = math.min(a.x, b.x);
  final y = math.min(a.y, b.y);
  return Rect.fromLTWH(x, y, (b.x - a.x).abs(), (b.y - a.y).abs());
}

/// Measures a [TextElement]'s rendered size using a [TextPainter].
Size measureText(TextElement el) {
  final tp = TextPainter(
    text: TextSpan(text: el.text, style: textStyleFor(el)),
    textDirection: ui.TextDirection.ltr,
  )..layout();
  return tp.size;
}

/// Builds the [TextStyle] used both for measuring and painting a text element.
TextStyle textStyleFor(TextElement el) => TextStyle(
  color: SketchBoardColors.black, // overridden by painter; only metrics matter
  fontSize: el.fontSize,
  height: 1.2,
  fontWeight: el.fontWeight == 'bold' ? FontWeight.bold : FontWeight.normal,
  fontStyle: el.fontStyle == 'italic' ? FontStyle.italic : FontStyle.normal,
);

/// Unrotated bounding box of [el] in world space.
Rect elementBounds(SketchElement el) {
  switch (el) {
    case FreehandElement():
      if (el.points.isEmpty) return Rect.zero;
      double minX = double.infinity, minY = double.infinity;
      double maxX = -double.infinity, maxY = -double.infinity;
      for (final p in el.points) {
        minX = math.min(minX, p.x);
        minY = math.min(minY, p.y);
        maxX = math.max(maxX, p.x);
        maxY = math.max(maxY, p.y);
      }
      return Rect.fromLTWH(
        minX - el.width / 2,
        minY - el.width / 2,
        (maxX - minX) + el.width,
        (maxY - minY) + el.width,
      );
    case TextElement():
      final s = measureText(el);
      return Rect.fromLTWH(el.position.x, el.position.y, s.width, s.height);
    case ImageElement():
      return Rect.fromLTWH(
        el.position.x,
        el.position.y,
        el.imageWidth,
        el.imageHeight,
      );
    case GroupElement():
      if (el.elements.isEmpty) return Rect.zero;
      Rect acc = elementBounds(el.elements.first);
      for (final sub in el.elements.skip(1)) {
        acc = acc.expandToInclude(elementBounds(sub));
      }
      return acc;
    case ShapeElement():
      final r = normalizeRect(el.start, el.end);
      return Rect.fromLTWH(
        r.left - el.width / 2,
        r.top - el.width / 2,
        r.width + el.width,
        r.height + el.width,
      );
    case RawElement():
      return Rect.zero;
  }
}

/// True when world-space [point] hits [el] (bounding-box test with [padding]).
bool hitTestElement(SketchElement el, Offset point, {double padding = 0}) {
  final b = elementBounds(el).inflate(padding);
  if (el.rotation == 0) return b.contains(point);
  // Rotate the point into the element's local frame, then test.
  final c = b.center;
  final dx = point.dx - c.dx;
  final dy = point.dy - c.dy;
  final cos = math.cos(-el.rotation);
  final sin = math.sin(-el.rotation);
  final local = Offset(c.dx + dx * cos - dy * sin, c.dy + dx * sin + dy * cos);
  return b.contains(local);
}

/// The eight resize anchors of a selection bounding box.
enum ResizeHandle { tl, t, tr, r, br, b, bl, l }

/// World-space positions of each [ResizeHandle] for bounding box [b].
Map<ResizeHandle, Offset> handlePositions(Rect b) => {
  ResizeHandle.tl: b.topLeft,
  ResizeHandle.t: b.topCenter,
  ResizeHandle.tr: b.topRight,
  ResizeHandle.r: b.centerRight,
  ResizeHandle.br: b.bottomRight,
  ResizeHandle.b: b.bottomCenter,
  ResizeHandle.bl: b.bottomLeft,
  ResizeHandle.l: b.centerLeft,
};

/// Bounding box enclosing every element, inflated by [padding]; null if empty.
Rect? sceneBounds(List<SketchElement> elements, {double padding = 0}) {
  Rect? acc;
  for (final el in elements) {
    if (el is RawElement) continue;
    final b = elementBounds(el);
    if (b == Rect.zero) continue;
    acc = acc == null ? b : acc.expandToInclude(b);
  }
  return acc?.inflate(padding);
}
