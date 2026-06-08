import 'package:flutter/services.dart';

class ClipboardHelper {
  ClipboardHelper._();
  static const _channel = MethodChannel('de.renier.tool_lab/clipboard');

  static Future<String?> getText() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    return data?.text;
  }

  static Future<void> setText(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }

  static Future<Uint8List?> getImagePng() async {
    try {
      final result = await _channel.invokeMethod<Uint8List>(
        'getClipboardImagePng',
      );
      if (result != null && result.isNotEmpty) return result;
    } on MissingPluginException {
      // platform does not support clipboard image reading
    } catch (_) {
      // ignore other errors
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
