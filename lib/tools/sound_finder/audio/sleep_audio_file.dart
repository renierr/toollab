import 'dart:io';

import '../../../helpers/wav_decoder.dart';
import 'sleep_flac_codec.dart';

WavAudioData? readSleepAudio(String path) {
  final file = File(path);
  if (!file.existsSync()) return null;
  final bytes = file.readAsBytesSync();
  return path.toLowerCase().endsWith('.flac')
      ? SleepFlacCodec.decode(bytes)
      : WavDecoder.decode(bytes);
}
