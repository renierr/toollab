import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'signature_geometry.dart';
import 'signature_models.dart';

/// Renders a single stroke onto [canvas] using the configured curve mode.
///
/// Ported from the browser-toolkit `drawSignaturePath`. Width is computed
/// per-segment from velocity/pressure with temporal smoothing.
void paintSignatureStroke(
  Canvas canvas,
  List<SignaturePoint> points,
  SignatureSettings s,
  Color color,
) {
  if (points.isEmpty) return;
  final base = s.penWidth;

  if (points.length == 1) {
    final p = points.first;
    canvas.drawCircle(
      Offset(p.x, p.y),
      base / 2,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
    return;
  }

  Paint strokePaint(double w) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;

  switch (s.curveMode) {
    case CurveMode.natural:
      final recentVels = <double>[];
      final recentPress = <double>[];
      double prevWidth = base;
      for (int i = 0; i < points.length - 1; i++) {
        final p0 = points[math.max(0, i - 1)];
        final p1 = points[i];
        final p2 = points[i + 1];
        final p3 = points[math.min(points.length - 1, i + 2)];
        final cp = catmullRomControls(p0, p1, p2, p3);

        final dist = _hypot(p1.x - p2.x, p1.y - p2.y);
        final dt = math.max(1.0, p2.timestamp - p1.timestamp);
        final vel = dist / dt;
        final press = (p1.pressure + p2.pressure) / 2.0;

        recentVels.add(vel);
        recentPress.add(press);
        if (recentVels.length > 5) recentVels.removeAt(0);
        if (recentPress.length > 5) recentPress.removeAt(0);
        final avgVel = recentVels.reduce((a, b) => a + b) / recentVels.length;
        final avgPress =
            recentPress.reduce((a, b) => a + b) / recentPress.length;

        final rawW = widthFromVelocityAndPressure(avgVel, avgPress, s);
        final w = prevWidth * s.widthSmoothing + rawW * (1 - s.widthSmoothing);
        prevWidth = w;

        final path = Path()
          ..moveTo(p1.x, p1.y)
          ..cubicTo(cp.c1x, cp.c1y, cp.c2x, cp.c2y, p2.x, p2.y);
        canvas.drawPath(path, strokePaint(w));
      }
      break;

    case CurveMode.fast:
      Offset cursor = Offset(points[0].x, points[0].y);
      SignaturePoint p1 = points[0];
      double prevWidth = base;
      for (int i = 1; i < points.length; i++) {
        final p2 = points[i];
        final mid = Offset((p1.x + p2.x) / 2, (p1.y + p2.y) / 2);
        final rawW = segmentWidth(p1, p2, s);
        final w = prevWidth * s.widthSmoothing + rawW * (1 - s.widthSmoothing);
        final path = Path()
          ..moveTo(cursor.dx, cursor.dy)
          ..quadraticBezierTo(p1.x, p1.y, mid.dx, mid.dy);
        canvas.drawPath(path, strokePaint(w));
        cursor = mid;
        p1 = p2;
        prevWidth = w;
      }
      canvas.drawLine(cursor, Offset(p1.x, p1.y), strokePaint(prevWidth));
      break;

    case CurveMode.draft:
      SignaturePoint p1 = points[0];
      double prevWidth = base;
      for (int i = 1; i < points.length; i++) {
        final p2 = points[i];
        final rawW = segmentWidth(p1, p2, s);
        final w = prevWidth * s.widthSmoothing + rawW * (1 - s.widthSmoothing);
        canvas.drawLine(Offset(p1.x, p1.y), Offset(p2.x, p2.y), strokePaint(w));
        p1 = p2;
        prevWidth = w;
      }
      break;

    case CurveMode.none:
      final path = Path()..moveTo(points[0].x, points[0].y);
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].x, points[i].y);
      }
      canvas.drawPath(path, strokePaint(base));
      break;
  }
}

double _hypot(double dx, double dy) => math.sqrt(dx * dx + dy * dy);

/// Live painter bound to the drawing state; repaints on every notify.
///
/// Strokes are stored in a fixed content space and fitted into the current
/// widget size via [transformGetter], so resizing only changes the transform.
class SignaturePainter extends CustomPainter {
  final Listenable repaintListenable;
  final List<List<SignaturePoint>> Function() pathsGetter;
  final List<SignaturePoint> Function() currentGetter;
  final SignatureSettings Function() settingsGetter;
  final ({double scale, double dx, double dy}) Function(Size view)
  transformGetter;

  SignaturePainter({
    required this.repaintListenable,
    required this.pathsGetter,
    required this.currentGetter,
    required this.settingsGetter,
    required this.transformGetter,
  }) : super(repaint: repaintListenable);

  @override
  void paint(Canvas canvas, Size size) {
    final s = settingsGetter();
    final color = colorFromHex(s.penColor);
    final t = transformGetter(size);
    canvas.save();
    canvas.translate(t.dx, t.dy);
    canvas.scale(t.scale);
    for (final stroke in pathsGetter()) {
      paintSignatureStroke(canvas, stroke, s, color);
    }
    final current = currentGetter();
    if (current.isNotEmpty) {
      paintSignatureStroke(canvas, current, s, color);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SignaturePainter oldDelegate) => false;
}

/// Rasterizes normalized stroke geometry to a transparent PNG at [s].dpi.
Future<Uint8List> renderSignaturePng(
  List<List<SignaturePoint>> paths,
  double width,
  double height,
  SignatureSettings s,
) async {
  final scale = s.dpi / 96.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.scale(scale);
  final color = colorFromHex(s.penColor);
  for (final stroke in paths) {
    paintSignatureStroke(canvas, stroke, s, color);
  }
  final picture = recorder.endRecording();
  final pxW = math.max(1, (width * scale).ceil());
  final pxH = math.max(1, (height * scale).ceil());
  final image = await picture.toImage(pxW, pxH);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return byteData!.buffer.asUint8List();
}
