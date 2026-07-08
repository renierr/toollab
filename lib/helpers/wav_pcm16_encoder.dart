import 'dart:typed_data';

/// Encodes interleaved Float32 PCM samples (range -1..1) into a 16-bit PCM WAV
/// byte buffer that SoLoud can [loadMem].
///
/// Shared by any tool that pre-renders audio (focus_noise loops, sound_finder
/// tone/noise loops) so the RIFF header + float→int16 conversion lives once.
class WavPcm16Encoder {
  WavPcm16Encoder._();

  /// [samples] is interleaved by channel. Only the first [frames] * [channels]
  /// values are written, so a render buffer with extra trailing frames (e.g. a
  /// crossfade tail) can be passed without copying.
  static Uint8List encode(
    Float32List samples, {
    required int frames,
    required int sampleRate,
    required int channels,
  }) {
    const int bytesPerSample = 2;
    final int dataBytes = frames * channels * bytesPerSample;
    final int byteRate = sampleRate * channels * bytesPerSample;
    final int blockAlign = channels * bytesPerSample;

    final ByteData bd = ByteData(44 + dataBytes);
    _writeAscii(bd, 0, 'RIFF');
    bd.setUint32(4, 36 + dataBytes, Endian.little);
    _writeAscii(bd, 8, 'WAVE');
    _writeAscii(bd, 12, 'fmt ');
    bd.setUint32(16, 16, Endian.little);
    bd.setUint16(20, 1, Endian.little); // PCM
    bd.setUint16(22, channels, Endian.little);
    bd.setUint32(24, sampleRate, Endian.little);
    bd.setUint32(28, byteRate, Endian.little);
    bd.setUint16(32, blockAlign, Endian.little);
    bd.setUint16(34, bytesPerSample * 8, Endian.little);
    _writeAscii(bd, 36, 'data');
    bd.setUint32(40, dataBytes, Endian.little);

    int offset = 44;
    final int count = frames * channels;
    for (int i = 0; i < count; i++) {
      final double s = samples[i].clamp(-1.0, 1.0);
      bd.setInt16(offset, (s * 32767).round(), Endian.little);
      offset += bytesPerSample;
    }
    return bd.buffer.asUint8List();
  }

  static void _writeAscii(ByteData bd, int offset, String text) {
    for (int i = 0; i < text.length; i++) {
      bd.setUint8(offset + i, text.codeUnitAt(i));
    }
  }
}
