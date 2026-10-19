import 'dart:io';
import 'dart:typed_data';

import 'memo_settings.dart';

/// A stored memo on disk with the stream facts read from its header.
class MemoClip {
  final String path;
  final String name;
  final String extension;
  final int sizeBytes;
  final DateTime modified;
  final Duration duration;
  final int sampleRate;
  final int channels;

  const MemoClip({
    required this.path,
    required this.name,
    required this.extension,
    required this.sizeBytes,
    required this.modified,
    required this.duration,
    required this.sampleRate,
    required this.channels,
  });

  MemoFormat? get format => MemoFormat.fromExtension(extension);
  bool get editable => format?.editable ?? false;
  String get mimeType => format?.mimeType ?? 'audio/$extension';
  String get fileName => '$name.$extension';

  /// Reads only the header, so listing stays cheap for long recordings.
  static Future<MemoClip> probe(File file) async {
    final stat = await file.stat();
    final base = file.uri.pathSegments.last;
    final dot = base.lastIndexOf('.');
    final ext = dot > 0 ? base.substring(dot + 1).toLowerCase() : '';
    final name = dot > 0 ? base.substring(0, dot) : base;

    _StreamInfo? info;
    try {
      final raf = await file.open();
      try {
        final head = await raf.read(64 * 1024);
        info = switch (ext) {
          'wav' => _parseWav(head, stat.size),
          'flac' => _parseFlac(head),
          _ => null,
        };
      } finally {
        await raf.close();
      }
    } catch (_) {}

    return MemoClip(
      path: file.path,
      name: name,
      extension: ext,
      sizeBytes: stat.size,
      modified: stat.modified,
      duration: info?.duration ?? Duration.zero,
      sampleRate: info?.sampleRate ?? 0,
      channels: info?.channels ?? 0,
    );
  }
}

typedef _StreamInfo = ({int sampleRate, int channels, Duration duration});

_StreamInfo? _parseWav(Uint8List head, int fileSize) {
  if (head.length < 12) return null;
  if (String.fromCharCodes(head, 0, 4) != 'RIFF') return null;
  if (String.fromCharCodes(head, 8, 12) != 'WAVE') return null;
  final view = ByteData.sublistView(head);
  int? channels;
  int? sampleRate;
  int? blockAlign;
  int pos = 12;
  while (pos + 8 <= head.length) {
    final id = String.fromCharCodes(head, pos, pos + 4);
    final size = view.getUint32(pos + 4, Endian.little);
    final body = pos + 8;
    if (id == 'fmt ' && body + 16 <= head.length) {
      channels = view.getUint16(body + 2, Endian.little);
      sampleRate = view.getUint32(body + 4, Endian.little);
      blockAlign = view.getUint16(body + 12, Endian.little);
    } else if (id == 'data') {
      if (channels == null || sampleRate == null || blockAlign == null) {
        return null;
      }
      final rest = fileSize - body;
      // An unfinalized header (crash mid-recording) leaves a placeholder size.
      final length = (size == 0 || size > rest) ? rest : size;
      if (sampleRate <= 0 || blockAlign <= 0) return null;
      final frames = length ~/ blockAlign;
      return (
        sampleRate: sampleRate,
        channels: channels,
        duration: Duration(microseconds: frames * 1000000 ~/ sampleRate),
      );
    }
    pos = body + size + (size.isOdd ? 1 : 0);
  }
  return null;
}

_StreamInfo? _parseFlac(Uint8List head) {
  // "fLaC", a 4-byte block header, then the 34-byte STREAMINFO block.
  if (head.length < 42) return null;
  if (String.fromCharCodes(head, 0, 4) != 'fLaC') return null;
  if (head[4] & 0x7F != 0) return null;
  const int s = 8;
  final sampleRate =
      (head[s + 10] << 12) | (head[s + 11] << 4) | (head[s + 12] >> 4);
  final channels = ((head[s + 12] >> 1) & 0x07) + 1;
  final totalSamples =
      ((head[s + 13] & 0x0F) << 32) |
      (head[s + 14] << 24) |
      (head[s + 15] << 16) |
      (head[s + 16] << 8) |
      head[s + 17];
  if (sampleRate <= 0) return null;
  return (
    sampleRate: sampleRate,
    channels: channels,
    duration: Duration(microseconds: totalSamples * 1000000 ~/ sampleRate),
  );
}
