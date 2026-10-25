import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/helpers/wav_decoder.dart';

/// 44-byte canonical PCM header; the data chunk is declared but not present.
Uint8List _header({
  required int sampleRate,
  required int channels,
  required int bits,
  required int dataSize,
}) {
  final bytes = Uint8List(44);
  final bd = ByteData.sublistView(bytes);
  void ascii(int offset, String text) {
    for (var i = 0; i < text.length; i++) {
      bd.setUint8(offset + i, text.codeUnitAt(i));
    }
  }

  final frameBytes = channels * (bits ~/ 8);
  ascii(0, 'RIFF');
  bd.setUint32(4, 36 + dataSize, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  bd.setUint32(16, 16, Endian.little);
  bd.setUint16(20, 1, Endian.little);
  bd.setUint16(22, channels, Endian.little);
  bd.setUint32(24, sampleRate, Endian.little);
  bd.setUint32(28, sampleRate * frameBytes, Endian.little);
  bd.setUint16(32, frameBytes, Endian.little);
  bd.setUint16(34, bits, Endian.little);
  ascii(36, 'data');
  bd.setUint32(40, dataSize, Endian.little);
  return bytes;
}

void main() {
  test('duration comes from the header alone', () {
    final header = _header(
      sampleRate: 44100,
      channels: 1,
      bits: 16,
      dataSize: 44100 * 2 * 15,
    );
    expect(WavDecoder.durationSeconds(header), closeTo(15, 1e-9));
  });

  test('stereo 24-bit duration accounts for the frame size', () {
    final header = _header(
      sampleRate: 48000,
      channels: 2,
      bits: 24,
      dataSize: 48000 * 6 * 5,
    );
    expect(WavDecoder.durationSeconds(header), closeTo(5, 1e-9));
  });

  test('invalid headers return null', () {
    expect(WavDecoder.durationSeconds(Uint8List(10)), isNull);
    expect(WavDecoder.durationSeconds(Uint8List(44)), isNull);
  });
}
