import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Reads Latin-script text from a photo for translation.
class TranslatorOcr {
  TranslatorOcr._();

  static Future<String> readImage(String path) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result = await recognizer.processImage(
        InputImage.fromFilePath(path),
      );
      return joinBlocks([
        for (final block in result.blocks)
          [for (final line in block.lines) line.text],
      ]);
    } finally {
      await recognizer.close();
    }
  }

  /// One block per line: OCR breaks sentences at the photo's line ends, and
  /// the translator works line by line.
  static String joinBlocks(List<List<String>> blocks) {
    final out = <String>[];
    for (final lines in blocks) {
      final buffer = StringBuffer();
      for (final raw in lines) {
        final line = raw.trim();
        if (line.isEmpty) continue;
        final text = buffer.toString();
        if (text.isEmpty) {
          buffer.write(line);
        } else if (RegExp(r'\p{L}-$', unicode: true).hasMatch(text)) {
          // "Bahnsteig-/kante" was split by the line end, "Nord-/Süd" is a compound.
          final lower = RegExp(r'^\p{Ll}', unicode: true).hasMatch(line);
          buffer
            ..clear()
            ..write(lower ? text.substring(0, text.length - 1) : text)
            ..write(line);
        } else {
          buffer.write(' $line');
        }
      }
      if (buffer.isNotEmpty) out.add(buffer.toString());
    }
    return out.join('\n');
  }
}
