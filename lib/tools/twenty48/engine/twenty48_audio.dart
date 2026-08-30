import 'dart:typed_data';

import 'package:tool_lab/helpers/wav_builder.dart';
import '../twenty48_audio_service.dart';

/// 2048's sound effects.
///
/// A merge is pitched by the value it produced, so the board sounds like it is
/// climbing — a 512 lands noticeably higher than a 4. The variants are
/// pre-rendered rather than built per merge so a chain of them costs nothing.
class Twenty48Sfx {
  Twenty48Sfx._();

  static const String slide = 'g48_slide';
  static const String mergePrefix = 'g48_merge_';
  static const int mergeVariants = 8;
  static const String win = 'g48_win';
  static const String gameOver = 'g48_over';
  static const String undo = 'g48_undo';

  /// The variant for a merged value: 4 is the lowest, 512 and up the highest.
  static String merge(int value) {
    var step = 0;
    var remaining = value;
    while (remaining > 4 && step < mergeVariants - 1) {
      remaining >>= 1;
      step++;
    }
    return '$mergePrefix$step';
  }

  static Future<void> load() async {
    final clips = <String, Uint8List>{
      slide: WavBuilder.noise(seconds: 0.06, gain: 0.05),
      for (var i = 0; i < mergeVariants; i++)
        '$mergePrefix$i': WavBuilder.tone(
          frequency: 300 * (1 + i * 0.22),
          seconds: 0.10,
          waveform: Waveform.triangle,
          gain: 0.2,
          slideHz: 90,
        ),
      win: WavBuilder.sequence(
        notes: const [
          ToneSpec(frequency: 523, seconds: 0.16, gain: 0.2),
          ToneSpec(frequency: 659, seconds: 0.16, gain: 0.2),
          ToneSpec(frequency: 784, seconds: 0.16, gain: 0.2),
          ToneSpec(frequency: 1047, seconds: 0.22, gain: 0.2),
        ],
        gapSeconds: 0.10,
      ),
      gameOver: WavBuilder.sequence(
        notes: const [
          ToneSpec(
            frequency: 330,
            seconds: 0.24,
            waveform: Waveform.sawtooth,
            gain: 0.18,
          ),
          ToneSpec(
            frequency: 247,
            seconds: 0.24,
            waveform: Waveform.sawtooth,
            gain: 0.18,
          ),
          ToneSpec(
            frequency: 165,
            seconds: 0.30,
            waveform: Waveform.sawtooth,
            gain: 0.18,
          ),
        ],
        gapSeconds: 0.18,
      ),
      undo: WavBuilder.tone(
        frequency: 420,
        seconds: 0.12,
        waveform: Waveform.triangle,
        gain: 0.16,
        slideHz: -160,
      ),
    };
    await Twenty48AudioService.instance.registerAll(clips);
  }
}
