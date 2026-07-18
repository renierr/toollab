import 'dart:convert';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

class NoteImageHelper {
  /// Processes raw image bytes: decodes, downscales if > 800px on either side,
  /// compresses to JPG with 80% quality, and base64 encodes it.
  /// Returns a NoteImageResult containing the generated unique ref label,
  /// the inline markdown tag, and the reference definition block.
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

      const maxDim = 800;
      img.Image processed = decoded;

      if (decoded.width > maxDim || decoded.height > maxDim) {
        double ratio = decoded.width / decoded.height;
        int newWidth, newHeight;
        if (decoded.width > decoded.height) {
          newWidth = maxDim;
          newHeight = (maxDim / ratio).round();
        } else {
          newHeight = maxDim;
          newWidth = (maxDim * ratio).round();
        }
        processed = img.copyResize(decoded, width: newWidth, height: newHeight);
      }

      final compressedBytes = img.encodeJpg(processed, quality: 80);
      final base64Str = base64Encode(compressedBytes);

      // Find unique reference index
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

      final inlineTag = '![$sanitizedName|300][$refLabel]';
      final refDefinition = '[$refLabel]: data:image/jpeg;base64,$base64Str';

      return NoteImageResult(
        refLabel: refLabel,
        inlineTag: inlineTag,
        refDefinition: refDefinition,
      );
    } catch (e) {
      return null;
    }
  }
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
