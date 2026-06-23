import 'dart:io';
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
    if (Platform.isLinux) {
      try {
        final hasWlPaste = await _isCommandAvailable('wl-paste');
        if (hasWlPaste) {
          final res = await Process.run('wl-paste', [
            '-t',
            'image/png',
          ], stdoutEncoding: null);
          if (res.exitCode == 0 && res.stdout is List<int>) {
            final bytes = Uint8List.fromList(res.stdout as List<int>);
            if (bytes.isNotEmpty) return bytes;
          }
        }
      } catch (_) {}

      try {
        final hasXclip = await _isCommandAvailable('xclip');
        if (hasXclip) {
          final res = await Process.run('xclip', [
            '-selection',
            'clipboard',
            '-t',
            'image/png',
            '-o',
          ], stdoutEncoding: null);
          if (res.exitCode == 0 && res.stdout is List<int>) {
            final bytes = Uint8List.fromList(res.stdout as List<int>);
            if (bytes.isNotEmpty) return bytes;
          }
        }
      } catch (_) {}
    }

    try {
      final image = await Pasteboard.image;
      if (image != null && image.isNotEmpty) return image;
    } catch (_) {
      // ignore errors
    }
    return null;
  }

  /// Copies [bytes] (PNG image data) to the clipboard. On Linux, tries wl-copy and
  /// xclip before falling back to Pasteboard.
  static Future<bool> copyImageBytes(Uint8List bytes) async {
    if (Platform.isLinux) {
      try {
        final hasWlCopy = await _isCommandAvailable('wl-copy');
        if (hasWlCopy) {
          final process = await Process.start('wl-copy', ['-t', 'image/png']);
          process.stdin.add(bytes);
          await process.stdin.close();
          final exitCode = await process.exitCode;
          if (exitCode == 0) return true;
        }
      } catch (_) {}

      try {
        final hasXclip = await _isCommandAvailable('xclip');
        if (hasXclip) {
          final process = await Process.start('xclip', [
            '-selection',
            'clipboard',
            '-t',
            'image/png',
            '-i',
          ]);
          process.stdin.add(bytes);
          await process.stdin.close();
          final exitCode = await process.exitCode;
          if (exitCode == 0) return true;
        }
      } catch (_) {}
    }

    try {
      await Pasteboard.writeImage(bytes);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _isCommandAvailable(String cmd) async {
    try {
      final res = await Process.run('which', [cmd]);
      return res.exitCode == 0;
    } catch (_) {
      return false;
    }
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
      await copyImageBytes(byteData.buffer.asUint8List());
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
