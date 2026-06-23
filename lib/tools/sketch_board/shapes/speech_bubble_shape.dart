import 'dart:math' as math;
import 'dart:ui';

import '../geometry/element_bounds.dart';
import '../models/sketch_element.dart';
import 'shape_renderer.dart';

class SpeechBubbleShape extends ShapeRenderer {
  const SpeechBubbleShape();

  @override
  void paint(Canvas canvas, ShapeElement el, Paint stroke, Paint? fill) {
    final r = normalizeRect(el.start, el.end);
    if (r.width < 1 || r.height < 1) return;
    final x = r.left, y = r.top, w = r.width, h = r.height;
    final radius = math.min(w, h) * 0.2;
    final tip = el.tailTip?.offset ?? Offset(x + w * 0.15, y + h + 20);

    final side = _nearestSide(tip, x, y, w, h, radius);
    final gap = _gapHalfWidth(tip, x, y, w, h, radius, side);
    final (pL, pR) = _gapPoints(tip, x, y, w, h, radius, gap, side);

    final path = Path()..moveTo(x + radius, y);
    if (side == _Side.top) {
      path
        ..lineTo(pL.dx, pL.dy)
        ..lineTo(tip.dx, tip.dy)
        ..lineTo(pR.dx, pR.dy);
    }
    path.lineTo(x + w - radius, y);
    path.quadraticBezierTo(x + w, y, x + w, y + radius);
    if (side == _Side.right) {
      path
        ..lineTo(pR.dx, pR.dy)
        ..lineTo(tip.dx, tip.dy)
        ..lineTo(pL.dx, pL.dy);
    }
    path.lineTo(x + w, y + h - radius);
    path.quadraticBezierTo(x + w, y + h, x + w - radius, y + h);
    if (side == _Side.bottom) {
      path
        ..lineTo(pR.dx, pR.dy)
        ..lineTo(tip.dx, tip.dy)
        ..lineTo(pL.dx, pL.dy);
    }
    path.lineTo(x + radius, y + h);
    path.quadraticBezierTo(x, y + h, x, y + h - radius);
    if (side == _Side.left) {
      path
        ..lineTo(pL.dx, pL.dy)
        ..lineTo(tip.dx, tip.dy)
        ..lineTo(pR.dx, pR.dy);
    }
    path.lineTo(x, y + radius);
    path.quadraticBezierTo(x, y, x + radius, y);
    path.close();

    fillThenStroke(canvas, path, stroke, fill);
  }
}

enum _Side { top, bottom, left, right }

double _distToSeg(Offset p, Offset a, Offset b) {
  final dx = b.dx - a.dx, dy = b.dy - a.dy;
  final l2 = dx * dx + dy * dy;
  if (l2 == 0) return (p - a).distance;
  var t = ((p.dx - a.dx) * dx + (p.dy - a.dy) * dy) / l2;
  t = t.clamp(0.0, 1.0);
  return (p - Offset(a.dx + t * dx, a.dy + t * dy)).distance;
}

_Side _nearestSide(
  Offset tip,
  double x,
  double y,
  double w,
  double h,
  double r,
) {
  final d1 = _distToSeg(tip, Offset(x + r, y), Offset(x + w - r, y));
  final d2 = _distToSeg(tip, Offset(x + r, y + h), Offset(x + w - r, y + h));
  final d3 = _distToSeg(tip, Offset(x, y + r), Offset(x, y + h - r));
  final d4 = _distToSeg(tip, Offset(x + w, y + r), Offset(x + w, y + h - r));
  final min = [d1, d2, d3, d4].reduce(math.min);
  if (min == d1) return _Side.top;
  if (min == d2) return _Side.bottom;
  if (min == d3) return _Side.left;
  return _Side.right;
}

double _gapHalfWidth(
  Offset tip,
  double x,
  double y,
  double w,
  double h,
  double r,
  _Side side,
) {
  final baseGap = (math.min(w, h) * 0.1) == 0 ? 12.0 : math.min(w, h) * 0.1;
  final outX = math.max(0.0, math.max(x - tip.dx, tip.dx - (x + w)));
  final outY = math.max(0.0, math.max(y - tip.dy, tip.dy - (y + h)));
  var gap = math.min(math.min(w, h) * 0.3, baseGap + (outX + outY) * 0.1);
  final sideLen = (side == _Side.top || side == _Side.bottom) ? w : h;
  final avail = math.max(0.0, sideLen - 2 * r);
  return math.min(gap, (avail / 2) * 0.8);
}

(Offset, Offset) _gapPoints(
  Offset tip,
  double x,
  double y,
  double w,
  double h,
  double r,
  double gap,
  _Side side,
) {
  if (side == _Side.top || side == _Side.bottom) {
    final cy = side == _Side.top ? y : y + h;
    final cx = math.max(x + r + gap, math.min(x + w - r - gap, tip.dx));
    return (Offset(cx - gap, cy), Offset(cx + gap, cy));
  }
  final cx = side == _Side.left ? x : x + w;
  final cy = math.max(y + r + gap, math.min(y + h - r - gap, tip.dy));
  return (Offset(cx, cy + gap), Offset(cx, cy - gap));
}
