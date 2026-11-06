import 'dart:io';
import 'dart:math' as math;
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

  /// Copies encoded image [bytes] as-is. Windows (GDI+) and Android decode any
  /// common format natively; the Linux tools declare `image/png`, so pass PNG
  /// there.
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

  /// Copies encoded image [bytes], passing a PNG within [maxDimension] through
  /// untouched and re-encoding anything else via [setImagePng]. [decoded], when
  /// the caller already holds it, spares a second decode.
  static Future<bool> copyEncodedImage(
    Uint8List bytes, {
    ui.Image? decoded,
    int maxDimension = 4096,
  }) async {
    // Only PNG passes through: JPEG and others may carry an EXIF orientation
    // that the native clipboard decoders ignore.
    final pngSize = _pngSize(bytes);
    if (pngSize != null &&
        math.max(pngSize.width, pngSize.height) <= maxDimension &&
        await copyImageBytes(bytes)) {
      return true;
    }

    if (decoded != null) {
      return setImagePng(decoded, maxDimension: maxDimension);
    }
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      final frame = await codec.getNextFrame();
      try {
        return await setImagePng(frame.image, maxDimension: maxDimension);
      } finally {
        frame.image.dispose();
      }
    } finally {
      codec.dispose();
    }
  }

  /// Whether [bytes] is a PNG that [copyEncodedImage] can pass through.
  static bool isPng(Uint8List bytes) {
    const signature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
    if (bytes.length < 24) return false;
    for (var i = 0; i < signature.length; i++) {
      if (bytes[i] != signature[i]) return false;
    }
    return true;
  }

  static ({int width, int height})? _pngSize(Uint8List bytes) {
    if (!isPng(bytes)) return null;
    final header = ByteData.sublistView(bytes, 16, 24);
    return (width: header.getUint32(0), height: header.getUint32(4));
  }

  /// Copies [image] to the clipboard as PNG. If the longest side exceeds
  /// [maxDimension], the image is downscaled with high-quality filtering first
  /// to keep clipboard payloads (and memory) reasonable.
  static Future<bool> setImagePng(
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
      return await copyImageBytes(byteData.buffer.asUint8List());
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
