import 'dart:io';
import 'dart:typed_data';

import '../../../helpers/wav_utils.dart';
import 'sleep_flac_codec.dart';

Int16List? _wavPcm(Uint8List bytes) {
  final info = readWavInfo(bytes);
  if (info == null ||
      info.format != 1 ||
      info.channels != 1 ||
      info.bitsPerSample != 16 ||
      info.blockAlign != 2 ||
      info.sampleRate <= 0 ||
      info.dataLength == 0 ||
      info.dataLength.isOdd) {
    return null;
  }
  final view = ByteData.sublistView(bytes);
  final samples = Int16List(info.dataLength ~/ 2);
  for (var i = 0; i < samples.length; i++) {
    samples[i] = view.getInt16(info.dataOffset + i * 2, Endian.little);
  }
  return samples;
}

bool sleepWavMatchesFlac((String, String) paths) {
  final (wavPath, flacPath) = paths;
  final wav = File(wavPath).readAsBytesSync();
  final pcm = _wavPcm(wav);
  final info = readWavInfo(wav);
  if (pcm == null || info == null) return false;
  final audio = SleepFlacCodec.decode(File(flacPath).readAsBytesSync());
  if (audio.sampleRate != info.sampleRate ||
      audio.samples.length != pcm.length) {
    return false;
  }
  for (var i = 0; i < pcm.length; i++) {
    if (audio.samples[i] != pcm[i] / 32768.0) return false;
  }
  return true;
}

bool compressSleepWav((String, String) paths) {
  final (wavPath, flacPath) = paths;
  final wav = File(wavPath).readAsBytesSync();
  final info = readWavInfo(wav);
  final pcm = _wavPcm(wav);
  if (info == null || pcm == null) return false;
  final flac = SleepFlacCodec.encode(pcm, info.sampleRate);
  if (flac.length >= wav.length) return false;
  File(flacPath).writeAsBytesSync(flac, flush: true);
  return sleepWavMatchesFlac(paths);
}
