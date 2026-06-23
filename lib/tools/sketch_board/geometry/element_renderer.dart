import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/sketch_element.dart';
import '../models/sketch_enums.dart';
import 'element_bounds.dart';

/// Resolves an already-decoded image for an [ImageElement.imageData] key, or
/// null if it is not ready yet.
typedef ImageResolver = ui.Image? Function(String imageData);

/// Pure, widget-free rendering of a single element onto [canvas] in world space.
///
/// Shared by the live [CustomPainter] and the PNG/thumbnail exporter so on-screen
/// and exported output are pixel-identical. Ported from the browser-toolkit
/// `drawElement` + per-shape `*Tool.draw` static methods (normal brush only).
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

  Paint strokePaint() => Paint()
    ..color = stroke.withValues(alpha: stroke.a * alpha)
    ..style = PaintingStyle.stroke
    ..strokeWidth = el.width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;

  Paint fillPaint(Color c) => Paint()
    ..color = c.withValues(alpha: c.a * alpha)
    ..style = PaintingStyle.fill
    ..isAntiAlias = true;

  switch (el) {
    case FreehandElement():
      _drawFreehand(canvas, el, strokePaint());
    case ShapeElement():
      _drawShape(canvas, el, stroke, fill, alpha, strokePaint, fillPaint);
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
      break; // unknown type — preserved in data, not rendered
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

void _drawShape(
  Canvas canvas,
  ShapeElement el,
  Color stroke,
  Color? fill,
  double alpha,
  Paint Function() strokePaint,
  Paint Function(Color) fillPaint,
) {
  final s = el.start.offset;
  final e = el.end.offset;
  final rect = normalizeRect(el.start, el.end);

  void fillThenStroke(Path p) {
    if (fill != null) canvas.drawPath(p, fillPaint(fill));
    canvas.drawPath(p, strokePaint());
  }

  switch (el.shapeType) {
    case 'line':
      canvas.drawLine(s, e, strokePaint());
    case 'rect':
      if (rect.width < 1 && rect.height < 1) return;
      if (fill != null) canvas.drawRect(rect, fillPaint(fill));
      canvas.drawRect(rect, strokePaint());
    case 'ellipse':
      if (rect.width < 1 && rect.height < 1) return;
      if (fill != null) canvas.drawOval(rect, fillPaint(fill));
      canvas.drawOval(rect, strokePaint());
    case 'triangle':
      if (rect.width < 1 || rect.height < 1) return;
      fillThenStroke(
        Path()
          ..moveTo(rect.left + rect.width / 2, rect.top)
          ..lineTo(rect.right, rect.bottom)
          ..lineTo(rect.left, rect.bottom)
          ..close(),
      );
    case 'diamond':
      if (rect.width < 1 || rect.height < 1) return;
      fillThenStroke(
        Path()
          ..moveTo(rect.left + rect.width / 2, rect.top)
          ..lineTo(rect.right, rect.top + rect.height / 2)
          ..lineTo(rect.left + rect.width / 2, rect.bottom)
          ..lineTo(rect.left, rect.top + rect.height / 2)
          ..close(),
      );
    case 'hexagon':
      if (rect.width < 1 || rect.height < 1) return;
      final x = rect.left, y = rect.top, w = rect.width, h = rect.height;
      fillThenStroke(
        Path()
          ..moveTo(x + w * 0.25, y)
          ..lineTo(x + w * 0.75, y)
          ..lineTo(x + w, y + h * 0.5)
          ..lineTo(x + w * 0.75, y + h)
          ..lineTo(x + w * 0.25, y + h)
          ..lineTo(x, y + h * 0.5)
          ..close(),
      );
    case 'checkmark':
      if (rect.width < 1 || rect.height < 1) return;
      final x = rect.left, y = rect.top, w = rect.width, h = rect.height;
      canvas.drawPath(
        Path()
          ..moveTo(x + w * 0.1, y + h * 0.55)
          ..lineTo(x + w * 0.35, y + h * 0.95)
          ..lineTo(x + w * 0.9, y + h * 0.1),
        strokePaint(),
      );
    case 'speech-bubble':
      _drawSpeechBubble(canvas, el, rect, fill, fillPaint, strokePaint);
    case 'arrow':
      _drawArrow(canvas, s, e, el.width, strokePaint(), startHead: false);
    case 'double-arrow':
      _drawArrow(canvas, s, e, el.width, strokePaint(), startHead: true);
  }
}

void _drawArrow(
  Canvas canvas,
  Offset start,
  Offset end,
  double strokeW,
  Paint paint, {
  required bool startHead,
}) {
  final dx = end.dx - start.dx;
  final dy = end.dy - start.dy;
  final len = math.sqrt(dx * dx + dy * dy);
  if (len < 1) return;

  final angle = math.atan2(dy, dx);
  final headLen = math.min(len * 0.3, math.max(strokeW * 3, 10.0));
  final spread = math.pi / 6;
  final halfBase = math.max(strokeW * 1.5, headLen * math.sin(spread));
  final perp = Offset(-math.sin(angle), math.cos(angle));
  final dir = Offset(math.cos(angle), math.sin(angle));

  final shaftStart = startHead ? start + dir * headLen : start;
  final shaftEnd = end - dir * headLen;
  canvas.drawLine(shaftStart, shaftEnd, paint);

  final fill = Paint()
    ..color = paint.color
    ..style = PaintingStyle.fill
    ..isAntiAlias = true;

  final endBase = end - dir * headLen;
  canvas.drawPath(
    Path()
      ..moveTo(end.dx, end.dy)
      ..lineTo(endBase.dx + perp.dx * halfBase, endBase.dy + perp.dy * halfBase)
      ..lineTo(endBase.dx - perp.dx * halfBase, endBase.dy - perp.dy * halfBase)
      ..close(),
    fill,
  );

  if (startHead) {
    final startBase = start + dir * headLen;
    canvas.drawPath(
      Path()
        ..moveTo(start.dx, start.dy)
        ..lineTo(
          startBase.dx + perp.dx * halfBase,
          startBase.dy + perp.dy * halfBase,
        )
        ..lineTo(
          startBase.dx - perp.dx * halfBase,
          startBase.dy - perp.dy * halfBase,
        )
        ..close(),
      fill,
    );
  }
}

void _drawSpeechBubble(
  Canvas canvas,
  ShapeElement el,
  Rect rect,
  Color? fill,
  Paint Function(Color) fillPaint,
  Paint Function() strokePaint,
) {
  if (rect.width < 1 || rect.height < 1) return;
  final x = rect.left, y = rect.top, w = rect.width, h = rect.height;
  final r = math.min(w, h) * 0.2;
  final tip = el.tailTip?.offset ?? Offset(x + w * 0.15, y + h + 20);

  double distToSeg(Offset p, Offset a, Offset b) {
    final dx = b.dx - a.dx, dy = b.dy - a.dy;
    final l2 = dx * dx + dy * dy;
    if (l2 == 0) return (p - a).distance;
    var t = ((p.dx - a.dx) * dx + (p.dy - a.dy) * dy) / l2;
    t = t.clamp(0.0, 1.0);
    return (p - Offset(a.dx + t * dx, a.dy + t * dy)).distance;
  }

  final d1 = distToSeg(tip, Offset(x + r, y), Offset(x + w - r, y));
  final d2 = distToSeg(tip, Offset(x + r, y + h), Offset(x + w - r, y + h));
  final d3 = distToSeg(tip, Offset(x, y + r), Offset(x, y + h - r));
  final d4 = distToSeg(tip, Offset(x + w, y + r), Offset(x + w, y + h - r));
  final minDist = [d1, d2, d3, d4].reduce(math.min);
  String side = 'bottom';
  if (minDist == d1) {
    side = 'top';
  } else if (minDist == d2) {
    side = 'bottom';
  } else if (minDist == d3) {
    side = 'left';
  } else if (minDist == d4) {
    side = 'right';
  }

  final baseGap = (math.min(w, h) * 0.1) == 0 ? 12.0 : math.min(w, h) * 0.1;
  final outX = math.max(0.0, math.max(x - tip.dx, tip.dx - (x + w)));
  final outY = math.max(0.0, math.max(y - tip.dy, tip.dy - (y + h)));
  var gap = math.min(math.min(w, h) * 0.3, baseGap + (outX + outY) * 0.1);
  final sideLen = (side == 'top' || side == 'bottom') ? w : h;
  final avail = math.max(0.0, sideLen - 2 * r);
  gap = math.min(gap, (avail / 2) * 0.8);

  Offset pL, pR;
  if (side == 'top' || side == 'bottom') {
    final cy = side == 'top' ? y : y + h;
    final cx = math.max(x + r + gap, math.min(x + w - r - gap, tip.dx));
    pL = Offset(cx - gap, cy);
    pR = Offset(cx + gap, cy);
  } else {
    final cx = side == 'left' ? x : x + w;
    final cy = math.max(y + r + gap, math.min(y + h - r - gap, tip.dy));
    pL = Offset(cx, cy + gap);
    pR = Offset(cx, cy - gap);
  }

  final path = Path()..moveTo(x + r, y);
  if (side == 'top') {
    path
      ..lineTo(pL.dx, pL.dy)
      ..lineTo(tip.dx, tip.dy)
      ..lineTo(pR.dx, pR.dy);
  }
  path.lineTo(x + w - r, y);
  path.quadraticBezierTo(x + w, y, x + w, y + r);
  if (side == 'right') {
    path
      ..lineTo(pR.dx, pR.dy)
      ..lineTo(tip.dx, tip.dy)
      ..lineTo(pL.dx, pL.dy);
  }
  path.lineTo(x + w, y + h - r);
  path.quadraticBezierTo(x + w, y + h, x + w - r, y + h);
  if (side == 'bottom') {
    path
      ..lineTo(pR.dx, pR.dy)
      ..lineTo(tip.dx, tip.dy)
      ..lineTo(pL.dx, pL.dy);
  }
  path.lineTo(x + r, y + h);
  path.quadraticBezierTo(x, y + h, x, y + h - r);
  if (side == 'left') {
    path
      ..lineTo(pL.dx, pL.dy)
      ..lineTo(tip.dx, tip.dy)
      ..lineTo(pR.dx, pR.dy);
  }
  path.lineTo(x, y + r);
  path.quadraticBezierTo(x, y, x + r, y);
  path.close();

  if (fill != null) canvas.drawPath(path, fillPaint(fill));
  canvas.drawPath(path, strokePaint());
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
    canvas.drawRect(dst, Paint()..color = const Color(0x22808080));
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
      ..color = const Color(0xFFFFFFFF).withValues(alpha: alpha),
  );
}
