import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:tool_lab/helpers/wav_decoder.dart';

/// Reduces one WAV chunk to a compact, level-normalized playback waveform.
Float32List? sleepWaveformEnvelope(String path, {int columns = 240}) {
  final audio = WavDecoder.decode(File(path).readAsBytesSync());
  if (audio == null || audio.samples.isEmpty) return null;
  final samples = audio.samples;
  final peaks = Float32List(columns);
  var loudest = 0.0;
  for (var column = 0; column < columns; column++) {
    final start = samples.length * column ~/ columns;
    final end = samples.length * (column + 1) ~/ columns;
    var peak = 0.0;
    for (var i = start; i < end; i++) {
      peak = math.max(peak, samples[i].abs());
    }
    peaks[column] = peak;
    loudest = math.max(loudest, peak);
  }
  if (loudest > 0) {
    for (var i = 0; i < peaks.length; i++) {
      peaks[i] = math.sqrt(peaks[i] / loudest);
    }
  }
  return peaks;
}
