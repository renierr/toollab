import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/helpers/wav_pcm16_encoder.dart';
import 'package:tool_lab/tools/sound_finder/audio/sleep_chunk_analyzer.dart';
import 'package:tool_lab/tools/sound_finder/audio/sleep_flac_codec.dart';
import 'package:tool_lab/tools/sound_finder/audio/sleep_playback_peak.dart';
import 'package:tool_lab/tools/sound_finder/audio/sleep_waveform_envelope.dart';

void main() {
  test('FLAC round trip preserves every PCM16 sample', () {
    final samples = Int16List.fromList([
      -32768,
      32767,
      0,
      for (var i = 0; i < 44100; i++) (12000 * math.sin(i / 30)).round(),
    ]);
    final encoded = SleepFlacCodec.encode(samples, 44100);
    final decoded = SleepFlacCodec.decode(encoded);
    expect(decoded.sampleRate, 44100);
    expect(decoded.samples.length, samples.length);
    for (var i = 0; i < samples.length; i++) {
      expect(decoded.samples[i], samples[i] / 32768.0);
    }
    expect(encoded.length, lessThan(samples.length * 2));
  });

  test('FLAC and WAV give the same analysis and waveform', () async {
    final base =
        '.agents/temp/sleep-flac-${DateTime.now().microsecondsSinceEpoch}';
    final wav = File('$base.wav');
    final flac = File('$base.flac');
    await wav.parent.create(recursive: true);
    try {
      final samples = Float32List.fromList([
        for (var i = 0; i < 16000; i++) 0.1 * math.sin(i / 13),
      ]);
      final wavBytes = WavPcm16Encoder.encode(
        samples,
        frames: samples.length,
        sampleRate: 8000,
        channels: 1,
      );
      final data = ByteData.sublistView(wavBytes);
      final pcm = Int16List.fromList([
        for (var i = 0; i < samples.length; i++)
          data.getInt16(44 + i * 2, Endian.little),
      ]);
      await wav.writeAsBytes(wavBytes);
      await flac.writeAsBytes(SleepFlacCodec.encode(pcm, 8000));
      expect(sleepWaveformEnvelope(flac.path), sleepWaveformEnvelope(wav.path));
      expect(sleepPlaybackPeak(flac.path), sleepPlaybackPeak(wav.path));
      expect(
        SleepChunkAnalyzer.analyzeFile(flac.path)?.toJson(),
        SleepChunkAnalyzer.analyzeFile(wav.path)?.toJson(),
      );
    } finally {
      if (await wav.exists()) await wav.delete();
      if (await flac.exists()) await flac.delete();
    }
  });

  test('invalid FLAC is rejected', () {
    expect(() => SleepFlacCodec.decode(Uint8List(64)), throwsFormatException);
  });
}
