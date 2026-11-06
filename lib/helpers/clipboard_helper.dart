import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:tool_lab/helpers/debug_log.dart';

class ClipboardHelper {
  ClipboardHelper._();

  static const MethodChannel _nativeChannel = MethodChannel(
    'de.renier.tool_lab/clipboard',
  );

  static const String _png = 'image/png';
  static const String _jpeg = 'image/jpeg';
  static const String _gif = 'image/gif';
  static const String _webp = 'image/webp';

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

  static Future<bool> _isCommandAvailable(String cmd) async {
    try {
      final res = await Process.run('which', [cmd]);
      return res.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Copies encoded image [bytes]. Android shares them untouched under their
  /// own MIME type; the desktops take a PNG within [maxDimension] as-is.
  /// Anything else is re-encoded to PNG, reusing [decoded] when given.
  /// [keepMetadata] false re-encodes formats that may carry EXIF (GPS).
  static Future<bool> copyImageBytes(
    Uint8List bytes, {
    ui.Image? decoded,
    int maxDimension = 4096,
    bool keepMetadata = true,
  }) async {
    final mimeType = imageMimeType(bytes);
    if (mimeType != null &&
        _canPassThrough(bytes, mimeType, maxDimension, keepMetadata)) {
      if (await _writeEncoded(bytes, mimeType)) {
        return true;
      }
      // The Linux writers share one code path, so a failed pass-through cannot
      // be recovered by re-encoding the same bytes.
      if (Platform.isLinux) {
        return false;
      }
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

  /// Whether [copyImageBytes] can hand [bytes] over without re-encoding,
  /// so callers know if keeping the source around pays off.
  static bool canCopyAsIs(Uint8List bytes) {
    final mimeType = imageMimeType(bytes);
    if (mimeType == null) return false;
    return Platform.isAndroid || mimeType == _png;
  }

  static bool _canPassThrough(
    Uint8List bytes,
    String mimeType,
    int maxDimension,
    bool keepMetadata,
  ) {
    if (Platform.isAndroid) {
      // Receivers read the file and honor its EXIF orientation themselves.
      if (!(keepMetadata || mimeType == _png || mimeType == _gif)) {
        return false;
      }
      if (mimeType != _png) return true;
      final header = ByteData.sublistView(bytes, 16, 24);
      return math.max(header.getUint32(0), header.getUint32(4)) <= maxDimension;
    }
    // The desktops only exchange PNG; JPEG and others may also carry an EXIF
    // orientation that the native decoders there would ignore.
    if (mimeType != _png) return false;
    final header = ByteData.sublistView(bytes, 16, 24);
    return math.max(header.getUint32(0), header.getUint32(4)) <= maxDimension;
  }

  /// Best-effort MIME type from the byte signature; null when unknown.
  @visibleForTesting
  static String? imageMimeType(Uint8List bytes) {
    bool startsWith(List<int> sig, [int offset = 0]) {
      if (bytes.length < offset + sig.length) return false;
      for (var i = 0; i < sig.length; i++) {
        if (bytes[offset + i] != sig[i]) return false;
      }
      return true;
    }

    if (bytes.length >= 24 &&
        startsWith(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) {
      return _png;
    }
    if (startsWith(const [0xFF, 0xD8, 0xFF])) return _jpeg;
    if (startsWith(const [0x47, 0x49, 0x46, 0x38])) return _gif;
    if (startsWith(const [0x52, 0x49, 0x46, 0x46]) &&
        startsWith(const [0x57, 0x45, 0x42, 0x50], 8)) {
      return _webp;
    }
    return null;
  }

  static Future<bool> _writeEncoded(Uint8List bytes, String mimeType) async {
    try {
      if (Platform.isAndroid) {
        final copied = await _nativeChannel.invokeMethod<bool>('writeImage', {
          'bytes': bytes,
          'mimeType': mimeType,
        });
        return copied == true;
      }
      if (mimeType != _png) return false;
      if (Platform.isWindows) {
        final copied = await _nativeChannel.invokeMethod<bool>(
          'writeImagePng',
          bytes,
        );
        return copied == true;
      }
      if (Platform.isLinux) return await _writeLinuxPng(bytes);
    } catch (e) {
      errorLog('ClipboardHelper: image copy failed: $e');
    }
    return false;
  }

  static Future<bool> _writeLinuxPng(Uint8List png) async {
    const wayland = ['wl-copy', '-t', _png];
    const x11 = ['xclip', '-selection', 'clipboard', '-t', _png, '-i'];
    final commands = Platform.environment.containsKey('WAYLAND_DISPLAY')
        ? [wayland, x11]
        : [x11, wayland];

    for (final command in commands) {
      try {
        // Both tools fork a background owner that serves the clipboard, so
        // the started process exits once it has read the input.
        final process = await Process.start(command.first, command.sublist(1));
        process.stdin.add(png);
        await process.stdin.close();
        if (await process.exitCode == 0) return true;
      } on ProcessException {
        // Tool not installed; try the next one.
      }
    }
    errorLog('ClipboardHelper: image copy needs wl-clipboard or xclip');
    return false;
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
      return await _writeEncoded(byteData.buffer.asUint8List(), _png);
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
