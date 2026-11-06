import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/helpers/clipboard_helper.dart';

void main() {
  group('ClipboardHelper imageMimeType', () {
    test('detects png from its signature', () {
      final bytes = Uint8List.fromList([
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
        0x00,
        0x00,
        0x00,
        0x0D,
        0x49,
        0x48,
        0x44,
        0x52,
        0x00,
        0x00,
        0x00,
        0x10,
        0x00,
        0x00,
        0x00,
        0x10,
      ]);
      expect(ClipboardHelper.imageMimeType(bytes), 'image/png');
    });

    test('detects jpeg from its signature', () {
      final bytes = Uint8List.fromList([
        0xFF,
        0xD8,
        0xFF,
        0xE0,
        0x00,
        0x10,
        0x4A,
        0x46,
        0x49,
        0x46,
      ]);
      expect(ClipboardHelper.imageMimeType(bytes), 'image/jpeg');
    });

    test('detects gif from its signature', () {
      final bytes = Uint8List.fromList([
        0x47,
        0x49,
        0x46,
        0x38,
        0x39,
        0x61,
        0x00,
        0x00,
      ]);
      expect(ClipboardHelper.imageMimeType(bytes), 'image/gif');
    });

    test('detects webp from its riff container', () {
      final bytes = Uint8List.fromList([
        0x52,
        0x49,
        0x46,
        0x46,
        0x00,
        0x00,
        0x00,
        0x00,
        0x57,
        0x45,
        0x42,
        0x50,
      ]);
      expect(ClipboardHelper.imageMimeType(bytes), 'image/webp');
    });

    test('returns null for unknown bytes', () {
      final bytes = Uint8List.fromList([0x00, 0x01, 0x02, 0x03]);
      expect(ClipboardHelper.imageMimeType(bytes), isNull);
    });
  });

  group('ClipboardHelper canCopyAsIs', () {
    test('keeps a png source copyable as-is', () {
      final bytes = Uint8List.fromList([
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
        0x00,
        0x00,
        0x00,
        0x0D,
        0x49,
        0x48,
        0x44,
        0x52,
        0x00,
        0x00,
        0x00,
        0x10,
        0x00,
        0x00,
        0x00,
        0x10,
      ]);
      expect(ClipboardHelper.canCopyAsIs(bytes), isTrue);
    });

    test('re-encodes formats without pass-through support', () {
      final bytes = Uint8List.fromList([
        0xFF,
        0xD8,
        0xFF,
        0xE0,
        0x00,
        0x10,
        0x4A,
        0x46,
        0x49,
        0x46,
      ]);
      expect(ClipboardHelper.canCopyAsIs(bytes), isFalse);
    });
  });
}
