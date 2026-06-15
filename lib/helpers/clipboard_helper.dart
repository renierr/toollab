import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:pasteboard/pasteboard.dart';

class ClipboardHelper {
  ClipboardHelper._();

  static Future<String?> getText() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    return data?.text;
  }

  static Future<void> setText(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }

  static Future<Uint8List?> getImagePng() async {
    try {
      final image = await Pasteboard.image;
      if (image != null && image.isNotEmpty) return image;
    } catch (_) {
      // ignore errors
    }
    return null;
  }

  /// Copies [image] to the clipboard as PNG. If the longest side exceeds
  /// [maxDimension], the image is downscaled with high-quality filtering first
  /// to keep clipboard payloads (and memory) reasonable.
  static Future<void> setImagePng(
    ui.Image image, {
    int maxDimension = 4096,
  }) async {
    ui.Image target = image;
    bool ownsTarget = false;

    final longest = image.width > image.height ? image.width : image.height;
    if (longest > maxDimension) {
      final scale = maxDimension / longest;
      final w = (image.width * scale).round();
      final h = (image.height * scale).round();

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawImageRect(
        image,
        ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
        ui.Paint()..filterQuality = ui.FilterQuality.high,
      );
      final picture = recorder.endRecording();
      target = await picture.toImage(w, h);
      picture.dispose();
      ownsTarget = true;
    }

    try {
      final byteData = await target.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Failed to encode image.');
      }
      await Pasteboard.writeImage(byteData.buffer.asUint8List());
    } finally {
      if (ownsTarget) target.dispose();
    }
  }

  static Future<bool> hasText() async {
    final text = await getText();
    return text != null && text.trim().isNotEmpty;
  }

  static Future<bool> hasImage() async {
    final image = await getImagePng();
    return image != null && image.isNotEmpty;
  }
}
