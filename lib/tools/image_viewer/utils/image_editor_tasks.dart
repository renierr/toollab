import 'dart:typed_data';
import 'package:image/image.dart' as img;

class RotateParams {
  final img.Image image;
  final int angle; // 90, 180, 270

  RotateParams(this.image, this.angle);
}

class FlipParams {
  final img.Image image;
  final String direction; // 'horizontal', 'vertical'

  FlipParams(this.image, this.direction);
}

class CropParams {
  final img.Image image;
  final int x;
  final int y;
  final int width;
  final int height;

  CropParams({
    required this.image,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });
}

class ResizeParams {
  final img.Image image;
  final int width;
  final int height;

  ResizeParams({
    required this.image,
    required this.width,
    required this.height,
  });
}

class ImageResizeParams {
  final img.Image image;
  final int width;
  final int height;
  final String format;
  final int quality;
  final bool preserveExif;

  ImageResizeParams({
    required this.image,
    required this.width,
    required this.height,
    required this.format,
    required this.quality,
    required this.preserveExif,
  });
}

img.Image decodeAndBakeOrientationTask(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw Exception('Could not decode image');
  }
  return img.bakeOrientation(decoded);
}

img.Image decodeImageTask(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw Exception('Could not decode snapshot image');
  }
  return decoded;
}

Uint8List encodePngTask(img.Image image) {
  return Uint8List.fromList(img.encodePng(image));
}

img.Image rotateImageTask(RotateParams params) {
  return img.copyRotate(params.image, angle: params.angle);
}

img.Image flipImageTask(FlipParams params) {
  final direction = params.direction == 'horizontal'
      ? img.FlipDirection.horizontal
      : img.FlipDirection.vertical;
  return img.copyFlip(params.image, direction: direction);
}

img.Image cropImageTask(CropParams params) {
  return img.copyCrop(
    params.image,
    x: params.x,
    y: params.y,
    width: params.width,
    height: params.height,
  );
}

img.Image resizeImageTask(ResizeParams params) {
  return img.copyResize(
    params.image,
    width: params.width,
    height: params.height,
    interpolation: img.Interpolation.cubic,
  );
}

Uint8List resizeAndEncodeTask(ImageResizeParams params) {
  final resized = img.copyResize(
    params.image,
    width: params.width,
    height: params.height,
    interpolation: img.Interpolation.cubic,
  );

  final targetImage = params.preserveExif ? resized : img.Image.from(resized);
  if (!params.preserveExif) {
    targetImage.exif = img.ExifData();
  }

  List<int> encoded;
  switch (params.format.toLowerCase()) {
    case 'jpg':
    case 'jpeg':
      encoded = img.encodeJpg(targetImage, quality: params.quality);
      if (params.preserveExif) {
        try {
          final injected = img.injectJpgExif(
            Uint8List.fromList(encoded),
            params.image.exif,
          );
          if (injected != null) {
            encoded = injected;
          }
        } catch (_) {
          // ignore or fallback
        }
      }
      break;
    case 'png':
      encoded = img.encodePng(targetImage);
      break;
    case 'bmp':
      encoded = img.encodeBmp(targetImage);
      break;
    case 'webp':
      encoded = img.encodeWebP(targetImage);
      break;
    default:
      encoded = img.encodePng(targetImage);
  }

  return Uint8List.fromList(encoded);
}

class RedactParams {
  final img.Image image;
  final int x;
  final int y;
  final int width;
  final int height;
  final String redactType;
  final double intensity;
  final int? colorValue;
  final List<double>? pathPoints;

  RedactParams({
    required this.image,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.redactType,
    required this.intensity,
    this.colorValue,
    this.pathPoints,
  });
}

bool _isPointInPolygon(
  double px,
  double py,
  List<double> pathPoints,
  int x,
  int y,
  int w,
  int h,
) {
  bool inside = false;
  final int count = pathPoints.length ~/ 2;
  if (count < 3) return false;

  int j = count - 1;
  for (int i = 0; i < count; i++) {
    final double ix = x + pathPoints[i * 2] * w;
    final double iy = y + pathPoints[i * 2 + 1] * h;
    final double jx = x + pathPoints[j * 2] * w;
    final double jy = y + pathPoints[j * 2 + 1] * h;

    if (((iy > py) != (jy > py)) &&
        (px < (jx - ix) * (py - iy) / (jy - iy) + ix)) {
      inside = !inside;
    }
    j = i;
  }
  return inside;
}

img.Image redactImageTask(RedactParams params) {
  final image = params.image;
  final x = params.x;
  final y = params.y;
  final w = params.width;
  final h = params.height;
  final type = params.redactType.toLowerCase();
  final intensity = params.intensity;
  final pathPoints = params.pathPoints;

  if (type == 'solid') {
    final colorVal = params.colorValue ?? 0xFF000000;
    final a = (colorVal >> 24) & 0xFF;
    final r = (colorVal >> 16) & 0xFF;
    final g = (colorVal >> 8) & 0xFF;
    final b = colorVal & 0xFF;
    final color = img.ColorRgba8(r, g, b, a);

    if (pathPoints != null && pathPoints.isNotEmpty) {
      for (int py = y; py < y + h; py++) {
        for (int px = x; px < x + w; px++) {
          if (px >= 0 && px < image.width && py >= 0 && py < image.height) {
            if (_isPointInPolygon(
              px.toDouble(),
              py.toDouble(),
              pathPoints,
              x,
              y,
              w,
              h,
            )) {
              image.setPixel(px, py, color);
            }
          }
        }
      }
      return image;
    } else {
      return img.fillRect(
        image,
        x1: x,
        y1: y,
        x2: x + w - 1,
        y2: y + h - 1,
        color: color,
      );
    }
  } else if (type == 'pixelate') {
    final blockSize = intensity.round().clamp(1, 100);
    for (int py = y; py < y + h; py += blockSize) {
      for (int px = x; px < x + w; px += blockSize) {
        final pixel = image.getPixel(
          px.clamp(0, image.width - 1),
          py.clamp(0, image.height - 1),
        );
        final r = pixel.r;
        final g = pixel.g;
        final b = pixel.b;
        final a = pixel.a;
        final color = img.ColorRgba8(
          r.toInt(),
          g.toInt(),
          b.toInt(),
          a.toInt(),
        );

        final int x2 = (px + blockSize - 1).clamp(x, x + w - 1);
        final int y2 = (py + blockSize - 1).clamp(y, y + h - 1);

        if (pathPoints != null && pathPoints.isNotEmpty) {
          for (int by = py; by <= y2; by++) {
            for (int bx = px; bx <= x2; bx++) {
              if (bx >= 0 && bx < image.width && by >= 0 && by < image.height) {
                if (_isPointInPolygon(
                  bx.toDouble(),
                  by.toDouble(),
                  pathPoints,
                  x,
                  y,
                  w,
                  h,
                )) {
                  image.setPixel(bx, by, color);
                }
              }
            }
          }
        } else {
          img.fillRect(image, x1: px, y1: py, x2: x2, y2: y2, color: color);
        }
      }
    }
    return image;
  } else if (type == 'blur') {
    final radius = intensity.round().clamp(1, 100);
    final cropped = img.copyCrop(image, x: x, y: y, width: w, height: h);
    final blurred = img.gaussianBlur(cropped, radius: radius);

    if (pathPoints != null && pathPoints.isNotEmpty) {
      for (int py = 0; py < h; py++) {
        for (int px = 0; px < w; px++) {
          final double imgX = (x + px).toDouble();
          final double imgY = (y + py).toDouble();
          if (imgX >= 0 &&
              imgX < image.width &&
              imgY >= 0 &&
              imgY < image.height) {
            if (_isPointInPolygon(imgX, imgY, pathPoints, x, y, w, h)) {
              final blurPixel = blurred.getPixel(px, py);
              image.setPixel(x + px, y + py, blurPixel);
            }
          }
        }
      }
      return image;
    } else {
      return img.compositeImage(image, blurred, dstX: x, dstY: y);
    }
  }

  return image;
}
