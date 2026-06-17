import 'package:flutter/foundation.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
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
  /// Returns the decoded text, or null when nothing is detected.
  static Future<String?> decodeImageFile(String path) async {
    try {
      final Code result = await zx.readBarcodeImagePathString(
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
      if (result.isValid && (result.text?.isNotEmpty ?? false)) {
        return result.text;
      }
    } catch (e) {
      debugPrint('[QrCodec] decode failed: $e');
    }
    return null;
  }
}
