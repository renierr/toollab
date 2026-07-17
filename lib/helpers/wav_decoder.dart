import 'dart:typed_data';

class WavAudioData {
  final Float32List samples;
  final int sampleRate;
  final int channels;

  const WavAudioData({
    required this.samples,
    required this.sampleRate,
    required this.channels,
  });
}

class WavDecoder {
  WavDecoder._();

  /// Decodes raw WAV file bytes into standard Float32 mono samples.
  static WavAudioData? decode(Uint8List bytes) {
    if (bytes.length < 44) return null;

    final ByteData bd = ByteData.sublistView(bytes);

    // Validate RIFF header
    if (_readAscii(bd, 0, 4) != 'RIFF' || _readAscii(bd, 8, 4) != 'WAVE') {
      return null;
    }

    // Find chunks
    int offset = 12;
    int? fmtOffset;
    int? dataOffset;
    int? dataSize;

    while (offset + 8 <= bytes.length) {
      final String chunkId = _readAscii(bd, offset, 4);
      final int chunkSize = bd.getUint32(offset + 4, Endian.little);
      if (chunkId == 'fmt ') {
        fmtOffset = offset + 8;
      } else if (chunkId == 'data') {
        dataOffset = offset + 8;
        dataSize = chunkSize;
        break;
      }
      offset += 8 + chunkSize;
    }

    if (fmtOffset == null || dataOffset == null || dataSize == null) {
      return null;
    }

    // Parse fmt chunk
    final int format = bd.getUint16(fmtOffset, Endian.little);
    final int channels = bd.getUint16(fmtOffset + 2, Endian.little);
    final int sampleRate = bd.getUint32(fmtOffset + 4, Endian.little);
    final int bitsPerSample = bd.getUint16(fmtOffset + 14, Endian.little);

    // Support PCM format (1) or Float format (3)
    if (format != 1 && format != 3) {
      return null;
    }

    if (channels < 1) return null;

    final int bytesPerSample = bitsPerSample ~/ 8;
    if (bytesPerSample == 0) return null;

    final int totalSamples = dataSize ~/ bytesPerSample;
    final int frames = totalSamples ~/ channels;

    final Float32List outSamples = Float32List(frames);

    int dataPtr = dataOffset;
    for (int i = 0; i < frames; i++) {
      if (dataPtr + bytesPerSample > bytes.length) break;

      double val = 0.0;
      if (bitsPerSample == 16) {
        val = bd.getInt16(dataPtr, Endian.little) / 32768.0;
      } else if (bitsPerSample == 8) {
        val = (bd.getUint8(dataPtr) - 128) / 128.0;
      } else if (bitsPerSample == 32) {
        if (format == 3) {
          val = bd.getFloat32(dataPtr, Endian.little);
        } else {
          val = bd.getInt32(dataPtr, Endian.little) / 2147483648.0;
        }
      }
      outSamples[i] = val.clamp(-1.0, 1.0);
      dataPtr += channels * bytesPerSample;
    }

    return WavAudioData(
      samples: outSamples,
      sampleRate: sampleRate,
      channels: channels,
    );
  }

  static String _readAscii(ByteData bd, int offset, int length) {
    final List<int> units = [];
    for (int i = 0; i < length; i++) {
      units.add(bd.getUint8(offset + i));
    }
    return String.fromCharCodes(units);
  }
}
