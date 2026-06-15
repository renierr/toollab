import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Stateless, GPU-accelerated `ui.Image` transforms used by the image viewer.
///
/// These run on the GPU via [Canvas] / [ui.PictureRecorder] and complete in
/// milliseconds, unlike the pure-Dart `image` package equivalents. They hold no
/// state — callers own the returned image and must dispose the source.

Future<ui.Image> canvasRotate(ui.Image source, int angle) async {
  final a = angle % 360;
  final swap = a == 90 || a == 270;
  final w = swap ? source.height : source.width;
  final h = swap ? source.width : source.height;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  switch (a) {
    case 90:
      canvas.translate(w.toDouble(), 0);
    case 180:
      canvas.translate(w.toDouble(), h.toDouble());
    case 270:
      canvas.translate(0, h.toDouble());
  }
  canvas.rotate(a * math.pi / 180);
  canvas.drawImage(source, Offset.zero, Paint());

  final picture = recorder.endRecording();
  final result = await picture.toImage(w, h);
  picture.dispose();
  return result;
}

Future<ui.Image> canvasFlip(ui.Image source, String direction) async {
  final w = source.width.toDouble();
  final h = source.height.toDouble();

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  if (direction == 'horizontal') {
    canvas.translate(w, 0);
    canvas.scale(-1, 1);
  } else {
    canvas.translate(0, h);
    canvas.scale(1, -1);
  }
  canvas.drawImage(source, Offset.zero, Paint());

  final picture = recorder.endRecording();
  final result = await picture.toImage(source.width, source.height);
  picture.dispose();
  return result;
}

Future<ui.Image> canvasCrop(ui.Image source, int x, int y, int w, int h) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  canvas.drawImageRect(
    source,
    Rect.fromLTWH(x.toDouble(), y.toDouble(), w.toDouble(), h.toDouble()),
    Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    Paint(),
  );

  final picture = recorder.endRecording();
  final result = await picture.toImage(w, h);
  picture.dispose();
  return result;
}

Future<ui.Image> canvasPixelate(
  ui.Image source,
  int x,
  int y,
  int w,
  int h,
  double blockSize, [
  List<Offset>? relativePathPoints,
]) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  canvas.drawImage(source, Offset.zero, Paint());

  final int tinyW = (w / blockSize).round().clamp(1, w);
  final int tinyH = (h / blockSize).round().clamp(1, h);

  final tinyRecorder = ui.PictureRecorder();
  final tinyCanvas = Canvas(tinyRecorder);
  tinyCanvas.drawImageRect(
    source,
    Rect.fromLTWH(x.toDouble(), y.toDouble(), w.toDouble(), h.toDouble()),
    Rect.fromLTWH(0, 0, tinyW.toDouble(), tinyH.toDouble()),
    Paint(),
  );
  final tinyPicture = tinyRecorder.endRecording();
  final tinyImage = await tinyPicture.toImage(tinyW, tinyH);
  tinyPicture.dispose();

  canvas.save();
  _clipToPath(canvas, relativePathPoints, x, y, w, h);

  canvas.drawImageRect(
    tinyImage,
    Rect.fromLTWH(0, 0, tinyW.toDouble(), tinyH.toDouble()),
    Rect.fromLTWH(x.toDouble(), y.toDouble(), w.toDouble(), h.toDouble()),
    Paint()..filterQuality = ui.FilterQuality.none,
  );
  canvas.restore();

  tinyImage.dispose();

  final picture = recorder.endRecording();
  final result = await picture.toImage(source.width, source.height);
  picture.dispose();
  return result;
}

Future<ui.Image> canvasBlur(
  ui.Image source,
  int x,
  int y,
  int w,
  int h,
  double sigma, [
  List<Offset>? relativePathPoints,
]) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  canvas.drawImage(source, Offset.zero, Paint());

  canvas.save();
  if (relativePathPoints != null && relativePathPoints.isNotEmpty) {
    _clipToPath(canvas, relativePathPoints, x, y, w, h);
  } else {
    canvas.clipRect(
      Rect.fromLTWH(x.toDouble(), y.toDouble(), w.toDouble(), h.toDouble()),
    );
  }

  final paint = Paint()
    ..imageFilter = ui.ImageFilter.blur(
      sigmaX: sigma,
      sigmaY: sigma,
      tileMode: TileMode.clamp,
    );
  canvas.drawImage(source, Offset.zero, paint);
  canvas.restore();

  final picture = recorder.endRecording();
  final result = await picture.toImage(source.width, source.height);
  picture.dispose();
  return result;
}

Future<ui.Image> canvasRedact(
  ui.Image source,
  int x,
  int y,
  int w,
  int h,
  String redactType,
  double intensity,
  Color? solidColor, [
  List<Offset>? relativePathPoints,
]) async {
  final type = redactType.toLowerCase();
  if (type == 'solid') {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImage(source, Offset.zero, Paint());

    canvas.save();
    _clipToPath(canvas, relativePathPoints, x, y, w, h);

    canvas.drawRect(
      Rect.fromLTWH(x.toDouble(), y.toDouble(), w.toDouble(), h.toDouble()),
      Paint()
        ..color = solidColor ?? Colors.black
        ..style = PaintingStyle.fill,
    );
    canvas.restore();

    final picture = recorder.endRecording();
    final result = await picture.toImage(source.width, source.height);
    picture.dispose();
    return result;
  } else if (type == 'pixelate') {
    return canvasPixelate(source, x, y, w, h, intensity, relativePathPoints);
  } else if (type == 'blur') {
    return canvasBlur(source, x, y, w, h, intensity, relativePathPoints);
  }
  return source;
}

/// Clips [canvas] to the polygon described by [relativePathPoints] (each point
/// in 0..1 relative to the `x,y,w,h` rect). No-op when the list is null/empty.
void _clipToPath(
  Canvas canvas,
  List<Offset>? relativePathPoints,
  int x,
  int y,
  int w,
  int h,
) {
  if (relativePathPoints == null || relativePathPoints.isEmpty) return;
  final path = ui.Path();
  path.moveTo(
    x + relativePathPoints.first.dx * w,
    y + relativePathPoints.first.dy * h,
  );
  for (int i = 1; i < relativePathPoints.length; i++) {
    path.lineTo(
      x + relativePathPoints[i].dx * w,
      y + relativePathPoints[i].dy * h,
    );
  }
  path.close();
  canvas.clipPath(path);
}
