import 'sleep_audio_file.dart';

double sleepPlaybackPeak(String path) {
  final audio = readSleepAudio(path);
  if (audio == null) return 1;
  var peak = 0.0;
  for (final sample in audio.samples) {
    if (sample.abs() > peak) peak = sample.abs();
  }
  return peak;
}
