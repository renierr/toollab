import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

class PathClipper extends CustomClipper<ui.Path> {
  final List<Offset> points;
  PathClipper(this.points);

  @override
  ui.Path getClip(Size size) {
    final Path path = Path();
    if (points.isEmpty) return path;
    path.moveTo(points.first.dx * size.width, points.first.dy * size.height);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx * size.width, points[i].dy * size.height);
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(PathClipper oldClipper) => oldClipper.points != points;
}

class DrawingPainter extends CustomPainter {
  final List<Offset> points;
  final Color color;

  DrawingPainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    path.moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(DrawingPainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.color != color;
}

class PathOutlinePainter extends CustomPainter {
  final List<Offset> points;
  final Color color;

  PathOutlinePainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final path = Path();
    path.moveTo(points.first.dx * size.width, points.first.dy * size.height);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx * size.width, points[i].dy * size.height);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(PathOutlinePainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.color != color;
}

class PixelatePainter extends CustomPainter {
  final img.Image decodedImage;
  final Rect normalizedRect;
  final double blockSize;

  PixelatePainter({
    required this.decodedImage,
    required this.normalizedRect,
    required this.blockSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final double stepX = blockSize;
    final double stepY = blockSize;

    final paint = Paint()..style = PaintingStyle.fill;

    final double srcLeft = normalizedRect.left * decodedImage.width;
    final double srcTop = normalizedRect.top * decodedImage.height;
    final double srcWidth = normalizedRect.width * decodedImage.width;
    final double srcHeight = normalizedRect.height * decodedImage.height;

    for (double y = 0; y < size.height; y += stepY) {
      for (double x = 0; x < size.width; x += stepX) {
        final double sampleX =
            srcLeft + (x + stepX / 2) * (srcWidth / size.width);
        final double sampleY =
            srcTop + (y + stepY / 2) * (srcHeight / size.height);

        final int clampX = sampleX.round().clamp(0, decodedImage.width - 1);
        final int clampY = sampleY.round().clamp(0, decodedImage.height - 1);

        final pixel = decodedImage.getPixel(clampX, clampY);
        final int r = pixel.r.toInt();
        final int g = pixel.g.toInt();
        final int b = pixel.b.toInt();
        final int a = pixel.a.toInt();

        paint.color = Color.fromARGB(a, r, g, b);

        final double w = math.min(stepX, size.width - x);
        final double h = math.min(stepY, size.height - y);

        canvas.drawRect(Rect.fromLTWH(x, y, w, h), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant PixelatePainter oldDelegate) {
    return oldDelegate.decodedImage != decodedImage ||
        oldDelegate.normalizedRect != normalizedRect ||
        oldDelegate.blockSize != blockSize;
  }
}
