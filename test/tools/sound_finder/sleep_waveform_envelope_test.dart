import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/helpers/wav_pcm16_encoder.dart';
import 'package:tool_lab/tools/sound_finder/audio/sleep_playback_peak.dart';
import 'package:tool_lab/tools/sound_finder/audio/sleep_waveform_envelope.dart';

void main() {
  test('loads non-flat normalized peaks from a quiet recorded WAV', () async {
    final file = File(
      '.agents/temp/sleep-waveform-${DateTime.now().microsecondsSinceEpoch}.wav',
    );
    await file.parent.create(recursive: true);
    try {
      final samples = Float32List.fromList([
        for (var i = 0; i < 8000; i++)
          i < 4000 ? (i.isEven ? 0.008 : -0.008) : 0,
      ]);
      await file.writeAsBytes(
        WavPcm16Encoder.encode(
          samples,
          frames: samples.length,
          sampleRate: 8000,
          channels: 1,
        ),
      );
      final path = file.path;
      final peaks = await Isolate.run(() => sleepWaveformEnvelope(path));
      expect(peaks, isNotNull);
      expect(peaks, hasLength(240));
      expect(peaks!.first, closeTo(1, 0.01));
      expect(peaks.last, 0);
      final measuredPeak = await Isolate.run(() => sleepPlaybackPeak(path));
      expect(measuredPeak, closeTo(0.008, 0.001));
    } finally {
      if (await file.exists()) await file.delete();
    }
  });
}
