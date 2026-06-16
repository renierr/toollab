import 'dart:math' as math;

import 'signature_models.dart';

/// Catmull-Rom → cubic Bézier control points for the segment p1→p2.
class BezierControls {
  final double c1x;
  final double c1y;
  final double c2x;
  final double c2y;
  const BezierControls(this.c1x, this.c1y, this.c2x, this.c2y);
}

BezierControls catmullRomControls(
  SignaturePoint p0,
  SignaturePoint p1,
  SignaturePoint p2,
  SignaturePoint p3,
) {
  return BezierControls(
    p1.x + (p2.x - p0.x) / 6.0,
    p1.y + (p2.y - p0.y) / 6.0,
    p2.x - (p3.x - p1.x) / 6.0,
    p2.y - (p3.y - p1.y) / 6.0,
  );
}

/// Maps a stroke velocity (px/ms) and pressure (0..1) to a clamped stroke width.
double widthFromVelocityAndPressure(
  double velocity,
  double pressure,
  SignatureSettings s,
) {
  final base = s.penWidth;
  // Faster movement → thinner line.
  final velFactor = 1.0 / (1.0 + velocity * s.velocitySensitivity);
  final velComponent = 1.0 - s.velocityInfluence * (1.0 - velFactor);
  final pressComponent = 1.0 - s.pressureInfluence * (1.0 - pressure);
  final w = base * velComponent * pressComponent;
  final minW = base * s.minWidthFactor;
  final maxW = base * s.maxWidthFactor;
  return w.clamp(minW, maxW);
}

/// Width for a single segment based on its instantaneous velocity/pressure.
double segmentWidth(SignaturePoint a, SignaturePoint b, SignatureSettings s) {
  final dist = _hypot(a.x - b.x, a.y - b.y);
  final dt = math.max(1.0, b.timestamp - a.timestamp);
  final vel = dist / dt;
  final press = (a.pressure + b.pressure) / 2.0;
  return widthFromVelocityAndPressure(vel, press, s);
}

double _hypot(double dx, double dy) => math.sqrt(dx * dx + dy * dy);

/// Ramer–Douglas–Peucker simplification, preserving each kept point's metadata.
List<SignaturePoint> simplifyRdp(List<SignaturePoint> points, double epsilon) {
  if (epsilon <= 0 || points.length < 3) return points;
  return _rdp(points, epsilon);
}

List<SignaturePoint> _rdp(List<SignaturePoint> pts, double epsilon) {
  if (pts.length < 3) return pts;
  final end = pts.length - 1;
  double dMax = 0;
  int index = 0;
  for (int i = 1; i < end; i++) {
    final d = _perpendicularDistance(pts[i], pts[0], pts[end]);
    if (d > dMax) {
      index = i;
      dMax = d;
    }
  }
  if (dMax > epsilon) {
    final left = _rdp(pts.sublist(0, index + 1), epsilon);
    final right = _rdp(pts.sublist(index), epsilon);
    return [...left.sublist(0, left.length - 1), ...right];
  }
  return [pts[0], pts[end]];
}

double _perpendicularDistance(
  SignaturePoint p,
  SignaturePoint a,
  SignaturePoint b,
) {
  final dx = b.x - a.x;
  final dy = b.y - a.y;
  final lenSq = dx * dx + dy * dy;
  if (lenSq == 0) return _hypot(p.x - a.x, p.y - a.y);
  final num = ((p.x - a.x) * dx + (p.y - a.y) * dy);
  final t = (num / lenSq).clamp(0.0, 1.0);
  final projX = a.x + t * dx;
  final projY = a.y + t * dy;
  return _hypot(p.x - projX, p.y - projY);
}
