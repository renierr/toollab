import 'dart:typed_data';

/// Wraps raw interleaved [pcm] in a canonical 44-byte WAV header.
/// [format] is 1 for integer PCM, 3 for IEEE float.
Uint8List buildPcmWav({
  required Uint8List pcm,
  required int sampleRate,
  required int channels,
  required int bitsPerSample,
  int format = 1,
}) {
  final int frameSize = channels * (bitsPerSample ~/ 8);
  final out = Uint8List(44 + pcm.length);
  final view = ByteData.sublistView(out);

  out.setRange(0, 4, 'RIFF'.codeUnits);
  view.setUint32(4, out.length - 8, Endian.little);
  out.setRange(8, 12, 'WAVE'.codeUnits);
  out.setRange(12, 16, 'fmt '.codeUnits);
  view.setUint32(16, 16, Endian.little);
  view.setUint16(20, format, Endian.little);
  view.setUint16(22, channels, Endian.little);
  view.setUint32(24, sampleRate, Endian.little);
  view.setUint32(28, sampleRate * frameSize, Endian.little);
  view.setUint16(32, frameSize, Endian.little);
  view.setUint16(34, bitsPerSample, Endian.little);
  out.setRange(36, 40, 'data'.codeUnits);
  view.setUint32(40, pcm.length, Endian.little);
  out.setRange(44, out.length, pcm);
  return out;
}

/// Widens a mono PCM WAV to stereo by duplicating every frame, because
/// SoLoud's freeverb filter asserts on non-stereo input.
///
/// Returns `null` when [wav] is not a mono PCM WAV — the caller must then treat
/// the clip as "channel count unknown" and skip the reverb filter.
Uint8List? widenWavToStereo(Uint8List wav) {
  if (wav.length < 12) return null;
  if (String.fromCharCodes(wav, 0, 4) != 'RIFF') return null;
  if (String.fromCharCodes(wav, 8, 12) != 'WAVE') return null;

  final view = ByteData.sublistView(wav);
  int fmt = -1;
  int data = -1;
  int dataLength = 0;

  int pos = 12;
  while (pos + 8 <= wav.length) {
    final String id = String.fromCharCodes(wav, pos, pos + 4);
    final int size = view.getUint32(pos + 4, Endian.little);
    final int body = pos + 8;
    if (id == 'fmt ') {
      fmt = body;
    } else if (id == 'data') {
      data = body;
      dataLength = size > wav.length - body ? wav.length - body : size;
    }
    pos = body + size + (size.isOdd ? 1 : 0);
  }
  if (fmt < 0 || fmt + 16 > wav.length || data < 0) return null;

  final int format = view.getUint16(fmt, Endian.little);
  final int channels = view.getUint16(fmt + 2, Endian.little);
  final int sampleRate = view.getUint32(fmt + 4, Endian.little);
  final int blockAlign = view.getUint16(fmt + 12, Endian.little);
  final int bitsPerSample = view.getUint16(fmt + 14, Endian.little);
  // 1 = PCM, 3 = IEEE float. Anything else is compressed, so frames are not
  // independently copyable.
  if (format != 1 && format != 3) return null;
  if (channels != 1 || blockAlign <= 0) return null;

  final int frames = dataLength ~/ blockAlign;
  final pcm = Uint8List(frames * blockAlign * 2);
  int write = 0;
  for (int f = 0; f < frames; f++) {
    final int read = data + f * blockAlign;
    pcm.setRange(write, write + blockAlign, wav, read);
    write += blockAlign;
    pcm.setRange(write, write + blockAlign, wav, read);
    write += blockAlign;
  }

  return buildPcmWav(
    pcm: pcm,
    sampleRate: sampleRate,
    channels: 2,
    bitsPerSample: bitsPerSample,
    format: format,
  );
}
