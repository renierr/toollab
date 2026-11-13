import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/helpers/wav_utils.dart';
import 'package:tool_lab/tools/sound_finder/audio/sleep_flac_codec.dart';
import 'package:tool_lab/tools/sound_finder/memo/memo_whisper_audio.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('memo_whisper_audio_');
  });

  tearDown(() async {
    await dir.delete(recursive: true);
  });

  Int16List sine(int rate, int seconds, {int channels = 1}) {
    final out = Int16List(rate * seconds * channels);
    for (var i = 0; i < rate * seconds; i++) {
      final v = (10000 * math.sin(2 * math.pi * 440 * i / rate)).round();
      for (var c = 0; c < channels; c++) {
        out[i * channels + c] = v;
      }
    }
    return out;
  }

  WavInfo convert(String source) {
    final target = '${dir.path}/out.wav';
    expect(convertMemoForWhisper(source, target), isTrue);
    final info = readWavInfo(File(target).readAsBytesSync())!;
    expect(info.sampleRate, whisperSampleRate);
    expect(info.channels, 1);
    expect(info.bitsPerSample, 16);
    return info;
  }

  test('downmixes and resamples a 48 kHz stereo WAV', () {
    final path = '${dir.path}/in.wav';
    File(path).writeAsBytesSync(
      buildPcmWav(
        pcm: sine(48000, 2, channels: 2).buffer.asUint8List(),
        sampleRate: 48000,
        channels: 2,
        bitsPerSample: 16,
      ),
    );
    expect(convert(path).frames, closeTo(32000, 1));
  });

  test('decodes FLAC through libFLAC', () {
    final path = '${dir.path}/in.flac';
    File(path).writeAsBytesSync(SleepFlacCodec.encode(sine(44100, 1), 44100));
    expect(convert(path).frames, closeTo(16000, 1));
  });

  test('rejects other formats', () {
    final path = '${dir.path}/in.mp3';
    File(path).writeAsBytesSync([1, 2, 3]);
    expect(convertMemoForWhisper(path, '${dir.path}/out.wav'), isFalse);
  });

  test('splits evenly into 30 s windows at the quietest spot', () {
    const rate = whisperSampleRate;
    final pcm = Int16List(70 * rate)..fillRange(0, 70 * rate, 8000);
    pcm.fillRange(23 * rate, 23 * rate + rate ~/ 5, 0);
    final starts = whisperChunkStarts(pcm);
    expect(starts.length, 3);
    expect(starts[1], inInclusiveRange(23 * rate, 23 * rate + rate ~/ 5));
    final ends = [...starts.skip(1), pcm.length];
    for (var i = 0; i < starts.length; i++) {
      expect(ends[i] - starts[i], lessThanOrEqualTo(30 * rate));
    }
    expect(whisperChunkStarts(Int16List(20 * rate)), [0]);
    expect(whisperChunkStarts(Int16List(29 * rate)), [0]);
    expect(whisperChunkStarts(Int16List(31 * rate)).length, 2);
  });
}
