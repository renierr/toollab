import 'package:flutter/services.dart';

/// Thin bridge to the Windows runner's built-in OCR (Windows.Media.Ocr / WinRT).
///
/// The native side lives in `windows/runner/ocr_handler.cpp` and is reached
/// over the `de.renier.tool_lab/ocr` MethodChannel. Windows-only; callers must
/// guard with `Platform.isWindows`.
class WindowsOcr {
  WindowsOcr._();

  static const MethodChannel _channel = MethodChannel('de.renier.tool_lab/ocr');

  /// Recognizes text from encoded image [imageBytes] (PNG/JPEG/etc.).
  /// Returns the recognized text, or an empty string when none is found.
  static Future<String> recognizeText(Uint8List imageBytes) async {
    final text = await _channel.invokeMethod<String>('recognizeText', {
      'bytes': imageBytes,
    });
    return text ?? '';
  }
}
