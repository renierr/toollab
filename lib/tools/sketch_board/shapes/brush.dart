import 'dart:math' as math;
import 'dart:ui';

/// Hand-drawn brush rendering (`shaky` + `natural`), ported from the reference
/// project's `brush-styles.ts` / `natural-brush.ts`. A seeded RNG keeps a given
/// stroke stable across repaints.

class _SeededRandom {
  int _state;
  _SeededRandom(int seed) : _state = seed == 0 ? 1 : seed;

  double next() {
    _state = (_state * 16807) % 2147483647;
    return (_state - 1) / 2147483646;
  }
}

bool isPlainBrush(String? brush) => brush == null || brush == 'normal';

List<Offset> _shakyPoints(
  Offset p1,
  Offset p2,
  double jitter,
  _SeededRandom rng,
) {
  final dist = (p2 - p1).distance;
  final segments = math.max(2, (dist / 16).floor());
  final pts = <Offset>[p1];
  for (int i = 1; i < segments; i++) {
    final t = i / segments;
    final x = p1.dx + (p2.dx - p1.dx) * t;
    final y = p1.dy + (p2.dy - p1.dy) * t;
    pts.add(
      Offset(x + (rng.next() - 0.5) * jitter, y + (rng.next() - 0.5) * jitter),
    );
  }
  pts.add(p2);
  return pts;
}

/// Variable-width "shaky" stroke. [color] carries the desired alpha; [fill]
/// (optional) fills the underlying polygon first.
void drawShakyStroke(
  Canvas canvas,
  List<Offset> points,
  Color color,
  double baseWidth, {
  bool closed = false,
  Color? fill,
}) {
  if (points.length < 2) return;

  final simplified = <Offset>[points.first];
  const minSq = 16.0;
  for (int i = 1; i < points.length; i++) {
    final p1 = simplified.last;
    final p2 = points[i];
    final dx = p2.dx - p1.dx, dy = p2.dy - p1.dy;
    if (dx * dx + dy * dy >= minSq || i == points.length - 1) {
      simplified.add(p2);
    }
  }
  if (simplified.length < 2) return;

  if (fill != null) {
    final fp = Path()..moveTo(simplified.first.dx, simplified.first.dy);
    for (int i = 1; i < simplified.length; i++) {
      fp.lineTo(simplified[i].dx, simplified[i].dy);
    }
    if (closed) fp.close();
    canvas.drawPath(
      fp,
      Paint()
        ..color = fill
        ..isAntiAlias = true,
    );
  }

  final jitter = math.max(1.0, 0.5 + baseWidth * 0.08);
  final seed =
      (simplified.first.dx +
              simplified.first.dy +
              simplified.length +
              baseWidth)
          .floor();
  final rng = _SeededRandom(seed);

  for (int p = 0; p < 2; p++) {
    final pJitter = jitter * (1 + p * 0.3);
    final center = <Offset>[];
    for (int i = 0; i < simplified.length - 1; i++) {
      final shaky = _shakyPoints(
        simplified[i],
        simplified[i + 1],
        pJitter,
        rng,
      );
      center.addAll(i == 0 ? shaky : shaky.skip(1));
    }
    if (closed) {
      final shaky = _shakyPoints(
        simplified.last,
        simplified.first,
        pJitter,
        rng,
      );
      center.addAll(shaky.skip(1));
    }

    final left = <Offset>[];
    final right = <Offset>[];
    double widthMod = 0.8 + rng.next() * 0.4;

    for (int i = 0; i < center.length; i++) {
      final pPrev = i > 0
          ? center[i - 1]
          : (closed ? center.last : center.first);
      final pCurr = center[i];
      final pNext = i + 1 < center.length
          ? center[i + 1]
          : (closed ? center.first : center[i]);

      final d1 = pCurr - pPrev;
      final d2 = pNext - pCurr;
      final len1 = d1.distance == 0 ? 1.0 : d1.distance;
      final len2 = d2.distance == 0 ? 1.0 : d2.distance;
      final n1 = Offset(-d1.dy / len1, d1.dx / len1);
      final n2 = Offset(-d2.dy / len2, d2.dx / len2);
      var n = Offset((n1.dx + n2.dx) / 2, (n1.dy + n2.dy) / 2);
      final nLen = n.distance == 0 ? 1.0 : n.distance;
      n = Offset(n.dx / nLen, n.dy / nLen);

      widthMod += (rng.next() - 0.5) * 0.12;
      widthMod = widthMod.clamp(0.65, 1.1);
      final isVertex = i == 0 || i == center.length - 1;
      final halfW = (isVertex ? baseWidth * 0.9 : baseWidth * widthMod) / 2;
      left.add(Offset(pCurr.dx + n.dx * halfW, pCurr.dy + n.dy * halfW));
      right.add(Offset(pCurr.dx - n.dx * halfW, pCurr.dy - n.dy * halfW));
    }

    if (left.isEmpty) continue;
    final path = Path()..moveTo(left.first.dx, left.first.dy);
    for (int i = 1; i < left.length - 1; i++) {
      final xc = (left[i].dx + left[i + 1].dx) / 2;
      final yc = (left[i].dy + left[i + 1].dy) / 2;
      path.quadraticBezierTo(left[i].dx, left[i].dy, xc, yc);
    }
    path.lineTo(left.last.dx, left.last.dy);
    path.lineTo(right.last.dx, right.last.dy);
    for (int i = right.length - 2; i > 0; i--) {
      final xc = (right[i].dx + right[i - 1].dx) / 2;
      final yc = (right[i].dy + right[i - 1].dy) / 2;
      path.quadraticBezierTo(right[i].dx, right[i].dy, xc, yc);
    }
    path.lineTo(right.first.dx, right.first.dy);
    path.close();

    final passAlpha = p == 0 ? color.a : color.a * 0.5;
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: passAlpha)
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );
  }
}

List<Offset> sharpenPath(List<Offset> points, [double strength = 0.95]) {
  if (points.length < 2) return points;
  final result = <Offset>[];
  for (int i = 0; i < points.length - 1; i++) {
    final p1 = points[i];
    final p2 = points[i + 1];
    result.add(p1);
    result.add(
      Offset(
        p1.dx + (p2.dx - p1.dx) * (1 - strength),
        p1.dy + (p2.dy - p1.dy) * (1 - strength),
      ),
    );
    result.add(
      Offset(
        p1.dx + (p2.dx - p1.dx) * strength,
        p1.dy + (p2.dy - p1.dy) * strength,
      ),
    );
  }
  result.add(points.last);
  return result;
}

double _simWidth(Offset p1, Offset p2, double base, double prev) {
  final dist = (p2 - p1).distance;
  final velocity = math.min(1.0, dist / 25);
  final velocityFactor = math.exp(-velocity * 1.5);
  const minF = 0.4, maxF = 1.2, influence = 0.8;
  final target = base * (1 - influence + velocityFactor * influence);
  final clamped = math.max(base * minF, math.min(base * maxF, target));
  return prev * 0.75 + clamped * 0.25;
}

/// Smooth, velocity-tapered "natural" stroke (open polyline).
void drawNaturalStroke(
  Canvas canvas,
  List<Offset> points,
  Color color,
  double baseWidth,
) {
  if (points.length < 2) return;
  Paint paint(double w) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;

  if (points.length == 2) {
    canvas.drawLine(points[0], points[1], paint(baseWidth));
    return;
  }

  double prev = baseWidth;
  for (int i = 0; i < points.length - 1; i++) {
    final p0 = points[math.max(0, i - 1)];
    final p1 = points[i];
    final p2 = points[i + 1];
    final p3 = points[math.min(points.length - 1, i + 2)];
    final c1 = Offset(p1.dx + (p2.dx - p0.dx) / 6, p1.dy + (p2.dy - p0.dy) / 6);
    final c2 = Offset(p2.dx - (p3.dx - p1.dx) / 6, p2.dy - (p3.dy - p1.dy) / 6);
    final w = _simWidth(p1, p2, baseWidth, prev);
    prev = w;
    final path = Path()
      ..moveTo(p1.dx, p1.dy)
      ..cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    canvas.drawPath(path, paint(w));
  }
}

/// Draws an open or closed point list honoring [brush] (`shaky`/`natural`),
/// filling [fill] for closed shapes. Returns false for the plain case so the
/// caller can fall back to its crisp drawing.
bool drawBrushPath(
  Canvas canvas,
  List<Offset> points,
  String? brush,
  Paint stroke,
  Paint? fill, {
  bool closed = false,
}) {
  if (isPlainBrush(brush)) return false;
  final color = stroke.color;
  final width = stroke.strokeWidth;
  if (brush == 'shaky') {
    drawShakyStroke(
      canvas,
      points,
      color,
      width,
      closed: closed,
      fill: fill?.color,
    );
    return true;
  }
  // natural
  if (fill != null && closed) {
    final fp = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      fp.lineTo(points[i].dx, points[i].dy);
    }
    fp.close();
    canvas.drawPath(fp, fill);
  }
  final pts = closed ? sharpenPath([...points, points.first]) : points;
  drawNaturalStroke(canvas, pts, color, width);
  return true;
}
