import 'dart:convert';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

class NoteImageHelper {
  static const _maxDim = 800;
  static const _jpegQuality = 80;

  static const _passthroughMimes = <img.ImageFormat, String>{
    img.ImageFormat.png: 'image/png',
    img.ImageFormat.jpg: 'image/jpeg',
    img.ImageFormat.webp: 'image/webp',
    img.ImageFormat.gif: 'image/gif',
  };

  /// Downscales to [_maxDim] on the longer side, then encodes: JPEG for opaque
  /// images, WebP/PNG (whichever is smaller) when transparency is present.
  /// An image that needs no resize keeps its original bytes if they are already
  /// smaller than a re-encode would be. Result is base64 in a ref definition.
  static Future<NoteImageResult?> processImage({
    required Uint8List imageBytes,
    required String name,
    required String currentContent,
  }) async {
    try {
      final decoded = img.decodeImage(imageBytes);
      if (decoded == null) {
        throw Exception('Failed to decode image.');
      }

      final resized = _fitWithin(decoded);
      var encoded = _encode(resized ?? decoded);

      if (resized == null) {
        final original = _passthrough(imageBytes);
        if (original != null && original.bytes.length < encoded.bytes.length) {
          encoded = original;
        }
      }

      final matches = RegExp(r'\[img_ref_(\d+)\]').allMatches(currentContent);
      int maxIndex = 0;
      for (final match in matches) {
        final index = int.tryParse(match.group(1) ?? '0') ?? 0;
        if (index > maxIndex) {
          maxIndex = index;
        }
      }
      final refLabel = 'img_ref_${maxIndex + 1}';
      final sanitizedName = name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');

      final base64Str = base64Encode(encoded.bytes);
      return NoteImageResult(
        refLabel: refLabel,
        inlineTag: '![$sanitizedName|300][$refLabel]',
        refDefinition: '[$refLabel]: ${encoded.mimeType};base64,$base64Str',
      );
    } catch (e) {
      return null;
    }
  }

  /// Null when the image already fits — the caller then skips re-encoding.
  static img.Image? _fitWithin(img.Image image) {
    if (image.width <= _maxDim && image.height <= _maxDim) return null;
    final ratio = image.width / image.height;
    return img.copyResize(
      image,
      width: image.width > image.height ? _maxDim : (_maxDim * ratio).round(),
      height: image.width > image.height ? (_maxDim / ratio).round() : _maxDim,
    );
  }

  static _EncodedImage _encode(img.Image image) {
    if (!_hasTransparency(image)) {
      return _EncodedImage(
        'data:image/jpeg',
        img.encodeJpg(image, quality: _jpegQuality),
      );
    }

    final png = _EncodedImage('data:image/png', img.encodePng(image));
    final webp = _encodeWebP(image);
    if (webp != null && webp.bytes.length < png.bytes.length) return webp;
    return png;
  }

  /// The bundled WebP encoder is lossless-only and fairly new — validate by
  /// decoding the result back before trusting it.
  static _EncodedImage? _encodeWebP(img.Image image) {
    try {
      final bytes = img.encodeWebP(image);
      final check = img.decodeWebP(bytes);
      if (check == null ||
          check.width != image.width ||
          check.height != image.height) {
        return null;
      }
      return _EncodedImage('data:image/webp', bytes);
    } catch (e) {
      return null;
    }
  }

  static _EncodedImage? _passthrough(Uint8List bytes) {
    final mime = _passthroughMimes[img.findFormatForData(bytes)];
    return mime == null ? null : _EncodedImage('data:$mime', bytes);
  }

  static bool _hasTransparency(img.Image image) {
    if (!image.hasAlpha) return false;
    for (final pixel in image) {
      if (pixel.a < pixel.maxChannelValue) return true;
    }
    return false;
  }
}

class _EncodedImage {
  final String mimeType;
  final Uint8List bytes;

  _EncodedImage(this.mimeType, this.bytes);
}

class NoteImageResult {
  final String refLabel;
  final String inlineTag;
  final String refDefinition;

  NoteImageResult({
    required this.refLabel,
    required this.inlineTag,
    required this.refDefinition,
  });
}
