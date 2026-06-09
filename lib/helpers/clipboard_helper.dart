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

  static Future<bool> hasText() async {
    final text = await getText();
    return text != null && text.trim().isNotEmpty;
  }

  static Future<bool> hasImage() async {
    final image = await getImagePng();
    return image != null && image.isNotEmpty;
  }
}
