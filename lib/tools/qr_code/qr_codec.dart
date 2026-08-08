import 'dart:io';
import 'package:tool_lab/helpers/debug_log.dart';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:image/image.dart' as img;

/// Thin wrapper around flutter_zxing so the UI never touches the FFI types
/// directly. Works on every supported platform (encode + image decode are pure
/// native calls; only the live camera widget is mobile-only).
class QrCodec {
  QrCodec._();

  /// Encodes [content] as a QR code and returns crisp PNG bytes of side [size].
  /// Throws if the content cannot be encoded (e.g. too long for the format).
  static Uint8List encodePng(
    String content, {
    int size = 512,
    EccLevel eccLevel = EccLevel.medium,
  }) {
    final result = zx.encodeBarcode(
      contents: content,
      params: EncodeParams(
        format: Format.qrCode,
        width: size,
        height: size,
        margin: 12,
        eccLevel: eccLevel,
      ),
    );

    final data = result.data;
    if (!result.isValid || data == null) {
      throw Exception(result.error ?? 'Failed to encode QR code');
    }

    final image = img.Image.fromBytes(
      width: size,
      height: size,
      bytes: data.buffer,
      numChannels: 1,
    );
    return Uint8List.fromList(img.encodePng(image));
  }

  /// Decodes the first QR/barcode found in the image at [path].
  /// Returns the decoded text, bounding box, and size, or null when nothing is detected.
  static Future<QrDecodeResult?> decodeImageFile(String path) async {
    try {
      var result = await zx.readBarcodeImagePathString(
        path,
        DecodeParams(
          // readBarcodeImagePath feeds the decoder RGB bytes, so the image
          // format must be rgb — the default (lum) would misread the data.
          imageFormat: ImageFormat.rgb,
          format: Format.any,
          tryHarder: true,
          tryRotate: true,
          tryInverted: true,
        ),
      );

      // Fallback to luminance (grayscale/optimized black-and-white) if RGB decoding fails.
      if (!result.isValid || result.text == null || result.text!.isEmpty) {
        result = await zx.readBarcodeImagePathString(
          path,
          DecodeParams(
            imageFormat: ImageFormat.lum,
            format: Format.any,
            tryHarder: true,
            tryRotate: true,
            tryInverted: true,
          ),
        );
      }

      final text = result.text;
      if (result.isValid && text != null && text.isNotEmpty) {
        Size? size;
        try {
          final bytes = await File(path).readAsBytes();
          final codec = await ui.instantiateImageCodec(bytes);
          final frameInfo = await codec.getNextFrame();
          size = Size(
            frameInfo.image.width.toDouble(),
            frameInfo.image.height.toDouble(),
          );
        } catch (e) {
          errorLog('[QrCodec] Failed to get image size: $e');
        }

        Rect? rect;
        final pos = result.position;
        if (pos != null) {
          final double minX = [
            pos.topLeftX,
            pos.topRightX,
            pos.bottomLeftX,
            pos.bottomRightX,
          ].reduce((a, b) => a < b ? a : b).toDouble();
          final double maxX = [
            pos.topLeftX,
            pos.topRightX,
            pos.bottomLeftX,
            pos.bottomRightX,
          ].reduce((a, b) => a > b ? a : b).toDouble();
          final double minY = [
            pos.topLeftY,
            pos.topRightY,
            pos.bottomLeftY,
            pos.bottomRightY,
          ].reduce((a, b) => a < b ? a : b).toDouble();
          final double maxY = [
            pos.topLeftY,
            pos.topRightY,
            pos.bottomLeftY,
            pos.bottomRightY,
          ].reduce((a, b) => a > b ? a : b).toDouble();

          if (size != null && pos.imageWidth > 0 && pos.imageHeight > 0) {
            final double scaleX = size.width / pos.imageWidth;
            final double scaleY = size.height / pos.imageHeight;
            rect = Rect.fromLTRB(
              minX * scaleX,
              minY * scaleY,
              maxX * scaleX,
              maxY * scaleY,
            );
          } else {
            rect = Rect.fromLTRB(minX, minY, maxX, maxY);
            size = Size(pos.imageWidth.toDouble(), pos.imageHeight.toDouble());
          }
        }

        return QrDecodeResult(text: text, rect: rect, size: size);
      }
    } catch (e) {
      errorLog('[QrCodec] decode failed: $e');
    }
    return null;
  }

  /// Decodes the first QR/barcode found in the image at [path] using ML Kit.
  /// Decodes an image file using ML Kit, returning text, bounding box, and size.
  static Future<QrDecodeResult?> decodeImageFileMlKit(String path) async {
    try {
      final inputImage = InputImage.fromFilePath(path);
      final scanner = BarcodeScanner(formats: [BarcodeFormat.all]);
      try {
        final barcodes = await scanner.processImage(inputImage);
        for (final barcode in barcodes) {
          final rawValue = barcode.rawValue;
          if (rawValue != null && rawValue.isNotEmpty) {
            Size? size;
            try {
              final bytes = await File(path).readAsBytes();
              final codec = await ui.instantiateImageCodec(bytes);
              final frameInfo = await codec.getNextFrame();
              size = Size(
                frameInfo.image.width.toDouble(),
                frameInfo.image.height.toDouble(),
              );
            } catch (e) {
              errorLog('[QrCodec] Failed to get image size: $e');
            }

            return QrDecodeResult(
              text: rawValue,
              rect: barcode.boundingBox,
              size: size,
            );
          }
        }
      } finally {
        await scanner.close();
      }
    } catch (e) {
      errorLog('[QrCodec] ML Kit decode failed: $e');
    }
    return null;
  }
}

class QrDecodeResult {
  final String text;
  final Rect? rect;
  final Size? size;

  const QrDecodeResult({required this.text, this.rect, this.size});
}
