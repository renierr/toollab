import 'dart:convert';
import 'dart:typed_data';

enum SqlValueType { nullValue, integer, real, text, blob }

SqlValueType sqlValueTypeOf(Object? value) {
  if (value == null) return SqlValueType.nullValue;
  if (value is int || value is bool) return SqlValueType.integer;
  if (value is double) return SqlValueType.real;
  if (value is Uint8List || value is List<int>) return SqlValueType.blob;
  return SqlValueType.text;
}

Uint8List? asBlob(Object? value) {
  if (value is Uint8List) return value;
  if (value is List<int>) return Uint8List.fromList(value);
  return null;
}

/// Single-line grid representation. BLOBs and multi-line text are collapsed —
/// the cell dialog shows the full value.
String formatCellPreview(Object? value, {int maxChars = 200}) {
  final blob = asBlob(value);
  if (blob != null) return 'BLOB (${blob.length} B)';
  final text = value?.toString() ?? '';
  final flat = text.replaceAll('\n', '⏎ ').replaceAll('\r', '');
  return flat.length > maxChars ? '${flat.substring(0, maxChars)}…' : flat;
}

String formatByteSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  var size = bytes / 1024;
  var unit = 0;
  while (size >= 1024 && unit < units.length - 1) {
    size /= 1024;
    unit++;
  }
  return '${size.toStringAsFixed(size >= 100 ? 0 : 1)} ${units[unit]}';
}

/// Classic hex dump (16 bytes per line) for the BLOB inspector.
String hexDump(Uint8List bytes, {int maxBytes = 4096}) {
  final limit = bytes.length < maxBytes ? bytes.length : maxBytes;
  final buffer = StringBuffer();
  for (var offset = 0; offset < limit; offset += 16) {
    final end = (offset + 16) < limit ? offset + 16 : limit;
    final chunk = bytes.sublist(offset, end);
    final hex = chunk
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join(' ')
        .padRight(47);
    final ascii = chunk
        .map((b) => b >= 32 && b < 127 ? String.fromCharCode(b) : '.')
        .join();
    buffer.writeln('${offset.toRadixString(16).padLeft(8, '0')}  $hex  $ascii');
  }
  if (limit < bytes.length) buffer.writeln('…');
  return buffer.toString();
}

/// Magic-byte sniff so an image BLOB can be previewed instead of hex-dumped.
bool looksLikeImage(Uint8List bytes) {
  if (bytes.length < 12) return false;
  final png = [0x89, 0x50, 0x4E, 0x47];
  if (_startsWith(bytes, png)) return true;
  if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) return true;
  if (_startsWith(bytes, [0x47, 0x49, 0x46, 0x38])) return true;
  if (_startsWith(bytes, [0x42, 0x4D])) return true;
  if (_startsWith(bytes, [0x52, 0x49, 0x46, 0x46]) &&
      _startsWith(bytes.sublist(8), [0x57, 0x45, 0x42, 0x50])) {
    return true;
  }
  return false;
}

bool _startsWith(Uint8List bytes, List<int> prefix) {
  if (bytes.length < prefix.length) return false;
  for (var i = 0; i < prefix.length; i++) {
    if (bytes[i] != prefix[i]) return false;
  }
  return true;
}

/// Best-effort UTF-8 decode of a BLOB, so text stored as a blob stays readable.
String? decodeBlobAsText(Uint8List bytes) {
  try {
    final text = utf8.decode(bytes);
    if (text.codeUnits.any((c) => c == 0)) return null;
    return text;
  } catch (_) {
    return null;
  }
}
