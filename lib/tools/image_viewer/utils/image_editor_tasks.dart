import 'dart:typed_data';
import 'package:image/image.dart' as img;

class EditParams {
  final Uint8List bytes;
  final String format; // 'png', 'jpg', 'webp', 'bmp'

  EditParams({required this.bytes, required this.format});
}

class RotateParams extends EditParams {
  final int angle; // 90, 180, 270

  RotateParams({
    required super.bytes,
    required super.format,
    required this.angle,
  });
}

class FlipParams extends EditParams {
  final String direction; // 'horizontal', 'vertical'

  FlipParams({
    required super.bytes,
    required super.format,
    required this.direction,
  });
}

class CropParams extends EditParams {
  final int x;
  final int y;
  final int width;
  final int height;

  CropParams({
    required super.bytes,
    required super.format,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });
}

class ImageResizeParams {
  final Uint8List bytes;
  final int width;
  final int height;
  final String format;
  final int quality;
  final bool preserveExif;

  ImageResizeParams({
    required this.bytes,
    required this.width,
    required this.height,
    required this.format,
    required this.quality,
    required this.preserveExif,
  });
}

Uint8List rotateImageTask(RotateParams params) {
  final decoded = img.decodeImage(params.bytes);
  if (decoded == null) {
    throw Exception('Could not decode image for rotation');
  }

  // Bake orientation first to ensure we work on visual pixels
  final oriented = img.bakeOrientation(decoded);

  final rotated = img.copyRotate(oriented, angle: params.angle);
  return Uint8List.fromList(_encodeByFormat(rotated, params.format));
}

Uint8List flipImageTask(FlipParams params) {
  final decoded = img.decodeImage(params.bytes);
  if (decoded == null) {
    throw Exception('Could not decode image for flipping');
  }

  final oriented = img.bakeOrientation(decoded);

  final direction = params.direction == 'horizontal'
      ? img.FlipDirection.horizontal
      : img.FlipDirection.vertical;

  final flipped = img.copyFlip(oriented, direction: direction);
  return Uint8List.fromList(_encodeByFormat(flipped, params.format));
}

Uint8List cropImageTask(CropParams params) {
  final decoded = img.decodeImage(params.bytes);
  if (decoded == null) {
    throw Exception('Could not decode image for cropping');
  }

  final oriented = img.bakeOrientation(decoded);

  final cropped = img.copyCrop(
    oriented,
    x: params.x,
    y: params.y,
    width: params.width,
    height: params.height,
  );
  return Uint8List.fromList(_encodeByFormat(cropped, params.format));
}

Uint8List resizeAndEncodeTask(ImageResizeParams params) {
  final decoded = img.decodeImage(params.bytes);
  if (decoded == null) {
    throw Exception('Could not decode original image');
  }

  // Bake orientation to ensure width/height match what the user sees in the UI
  final oriented = img.bakeOrientation(decoded);

  final resized = img.copyResize(
    oriented,
    width: params.width,
    height: params.height,
    interpolation: img.Interpolation.average,
  );

  if (!params.preserveExif) {
    resized.exif = img.ExifData();
  }

  List<int> encoded;
  switch (params.format.toLowerCase()) {
    case 'jpg':
    case 'jpeg':
      encoded = img.encodeJpg(resized, quality: params.quality);
      if (params.preserveExif) {
        try {
          final injected = img.injectJpgExif(
            Uint8List.fromList(encoded),
            decoded.exif,
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
      encoded = img.encodePng(resized);
      break;
    case 'bmp':
      encoded = img.encodeBmp(resized);
      break;
    default:
      encoded = img.encodePng(resized);
  }

  return Uint8List.fromList(encoded);
}

List<int> _encodeByFormat(img.Image image, String format) {
  switch (format.toLowerCase()) {
    case 'jpg':
    case 'jpeg':
      return img.encodeJpg(image, quality: 95);
    case 'png':
      return img.encodePng(image);
    case 'bmp':
      return img.encodeBmp(image);
    default:
      return img.encodePng(image);
  }
}
