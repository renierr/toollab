import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

/// Result of converting NV21 camera frame to JPEG.
class ConversionResult {
  final Uint8List jpegBytes;
  final Rect rotatedRect;
  final Size rotatedSize;

  const ConversionResult({
    required this.jpegBytes,
    required this.rotatedRect,
    required this.rotatedSize,
  });
}

/// Converts an NV21 CameraImage to JPEG bytes, rotating both the image and
/// the barcode bounding box to stand upright in portrait mode.
ConversionResult convertNv21ToJpeg({
  required CameraImage image,
  required int rotationDegrees,
  required Rect barcodeRect,
}) {
  final width = image.width;
  final height = image.height;
  final rgbImage = img.Image(width: width, height: height);

  if (image.planes.length >= 3) {
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final yBuffer = yPlane.bytes;
    final uBuffer = uPlane.bytes;
    final vBuffer = vPlane.bytes;

    final yRowStride = yPlane.bytesPerRow;
    final uRowStride = uPlane.bytesPerRow;
    final vRowStride = vPlane.bytesPerRow;

    final yPixelStride = yPlane.bytesPerPixel ?? 1;
    final uPixelStride = uPlane.bytesPerPixel ?? 1;
    final vPixelStride = vPlane.bytesPerPixel ?? 1;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final yIndex = y * yRowStride + x * yPixelStride;
        final uvX = x ~/ 2;
        final uvY = y ~/ 2;
        final uIndex = uvY * uRowStride + uvX * uPixelStride;
        final vIndex = uvY * vRowStride + uvX * vPixelStride;

        if (yIndex >= yBuffer.length ||
            uIndex >= uBuffer.length ||
            vIndex >= vBuffer.length) {
          continue;
        }

        final yVal = yBuffer[yIndex];
        final uVal = uBuffer[uIndex];
        final vVal = vBuffer[vIndex];

        final r = (yVal + ((vVal - 128) * 1436 ~/ 1024)).clamp(0, 255);
        final g =
            (yVal - ((uVal - 128) * 352 ~/ 1024) - ((vVal - 128) * 731 ~/ 1024))
                .clamp(0, 255);
        final b = (yVal + ((uVal - 128) * 1814 ~/ 1024)).clamp(0, 255);

        rgbImage.setPixelRgb(x, y, r, g, b);
      }
    }
  } else {
    // Fallback: 1 plane NV21
    final yPlane = image.planes[0];
    final yBuffer = yPlane.bytes;
    final yRowStride = yPlane.bytesPerRow;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final yIndex = y * yRowStride + x;
        final uvIndex = width * height + (y ~/ 2) * width + (x ~/ 2) * 2;

        if (yIndex >= yBuffer.length || uvIndex + 1 >= yBuffer.length) continue;

        final yVal = yBuffer[yIndex];
        final vVal = yBuffer[uvIndex];
        final uVal = yBuffer[uvIndex + 1];

        final r = (yVal + ((vVal - 128) * 1436 ~/ 1024)).clamp(0, 255);
        final g =
            (yVal - ((uVal - 128) * 352 ~/ 1024) - ((vVal - 128) * 731 ~/ 1024))
                .clamp(0, 255);
        final b = (yVal + ((uVal - 128) * 1814 ~/ 1024)).clamp(0, 255);

        rgbImage.setPixelRgb(x, y, r, g, b);
      }
    }
  }

  // Rotate image and coordinates
  img.Image finalImage = rgbImage;
  Rect rotatedRect = barcodeRect;
  Size rotatedSize = Size(width.toDouble(), height.toDouble());

  if (rotationDegrees == 90) {
    finalImage = img.copyRotate(rgbImage, angle: 90);
    rotatedSize = Size(height.toDouble(), width.toDouble());
    rotatedRect = Rect.fromLTRB(
      height - barcodeRect.bottom,
      barcodeRect.left,
      height - barcodeRect.top,
      barcodeRect.right,
    );
  } else if (rotationDegrees == 180) {
    finalImage = img.copyRotate(rgbImage, angle: 180);
    rotatedRect = Rect.fromLTRB(
      width - barcodeRect.right,
      height - barcodeRect.bottom,
      width - barcodeRect.left,
      height - barcodeRect.top,
    );
  } else if (rotationDegrees == 270) {
    finalImage = img.copyRotate(rgbImage, angle: 270);
    rotatedSize = Size(height.toDouble(), width.toDouble());
    rotatedRect = Rect.fromLTRB(
      barcodeRect.top,
      width - barcodeRect.right,
      barcodeRect.bottom,
      width - barcodeRect.left,
    );
  }

  final jpeg = img.encodeJpg(finalImage, quality: 85);
  return ConversionResult(
    jpegBytes: Uint8List.fromList(jpeg),
    rotatedRect: rotatedRect,
    rotatedSize: rotatedSize,
  );
}
