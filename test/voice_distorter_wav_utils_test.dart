import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/tools/voice_distorter/engine/wav_utils.dart';

Uint8List _monoWav(List<int> samples, {int sampleRate = 44100}) {
  final pcm = Uint8List(samples.length * 2);
  final view = ByteData.sublistView(pcm);
  for (int i = 0; i < samples.length; i++) {
    view.setInt16(i * 2, samples[i], Endian.little);
  }
  return buildPcmWav(
    pcm: pcm,
    sampleRate: sampleRate,
    channels: 1,
    bitsPerSample: 16,
  );
}

void main() {
  group('widenWavToStereo', () {
    test('duplicates every frame and fixes up the header', () {
      final result = widenWavToStereo(_monoWav([100, -200, 300]));
      expect(result, isNotNull);

      final view = ByteData.sublistView(result!);
      expect(view.getUint16(22, Endian.little), 2, reason: 'channels');
      expect(view.getUint32(24, Endian.little), 44100, reason: 'sample rate');
      expect(view.getUint16(32, Endian.little), 4, reason: 'block align');
      expect(view.getUint32(28, Endian.little), 44100 * 4, reason: 'byte rate');
      expect(view.getUint16(34, Endian.little), 16, reason: 'bit depth');
      expect(view.getUint32(4, Endian.little), result.length - 8);
      expect(view.getUint32(40, Endian.little), 3 * 4, reason: 'data size');

      final samples = [
        for (int i = 0; i < 6; i++) view.getInt16(44 + i * 2, Endian.little),
      ];
      expect(samples, [100, 100, -200, -200, 300, 300]);
    });

    test('rejects input that is not a mono PCM wav', () {
      expect(widenWavToStereo(Uint8List(0)), isNull);
      expect(
        widenWavToStereo(Uint8List.fromList('not a wav file'.codeUnits)),
        isNull,
      );

      final stereo = buildPcmWav(
        pcm: Uint8List(16),
        sampleRate: 44100,
        channels: 2,
        bitsPerSample: 16,
      );
      expect(widenWavToStereo(stereo), isNull, reason: 'already stereo');
    });
  });
}
