import 'dart:io';

import 'package:tool_lab/helpers/wav_decoder.dart';

double sleepPlaybackPeak(String path) {
  final audio = WavDecoder.decode(File(path).readAsBytesSync());
  if (audio == null) return 1;
  var peak = 0.0;
  for (final sample in audio.samples) {
    if (sample.abs() > peak) peak = sample.abs();
  }
  return peak;
}
