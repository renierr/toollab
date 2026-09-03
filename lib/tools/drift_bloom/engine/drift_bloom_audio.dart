import 'dart:typed_data';

import 'package:tool_lab/helpers/wav_builder.dart';
import '../drift_bloom_audio_service.dart';

/// Drift Bloom's sound effects — airy chimes that lift with the combo.
class DriftBloomSfx {
  DriftBloomSfx._();

  static const String _bloomPrefix = 'db_bloom_';
  static const int _bloomVariants = 5;
  static const String goldenBloom = 'db_golden';
  static const String padLoop = 'db_pad';

  /// The variant for a bloom: higher combos ring higher.
  static String bloom(int combo) =>
      '$_bloomPrefix${(combo - 1).clamp(0, _bloomVariants - 1)}';

  static Future<void> load() async {
    final clips = <String, Uint8List>{
      for (var i = 0; i < _bloomVariants; i++)
        '$_bloomPrefix$i': WavBuilder.tone(
          frequency: 520 * (1 + i * 0.2),
          seconds: 0.3,
          gain: 0.22,
          slideHz: 180,
          decay: 4.0,
          attackSeconds: 0.01,
        ),
      goldenBloom: WavBuilder.sequence(
        notes: const [
          ToneSpec(
            frequency: 660,
            seconds: 0.16,
            waveform: Waveform.triangle,
            gain: 0.2,
          ),
          ToneSpec(
            frequency: 880,
            seconds: 0.16,
            waveform: Waveform.triangle,
            gain: 0.2,
          ),
          ToneSpec(
            frequency: 1320,
            seconds: 0.32,
            waveform: Waveform.triangle,
            gain: 0.22,
          ),
        ],
        gapSeconds: 0.1,
      ),
      padLoop: WavBuilder.mix([
        WavBuilder.tone(frequency: 146.8, seconds: 8, gain: 0.09, decay: 0),
        WavBuilder.tone(frequency: 220, seconds: 8, gain: 0.06, decay: 0),
        WavBuilder.tone(frequency: 293.7, seconds: 8, gain: 0.045, decay: 0),
      ]),
    };
    await DriftBloomAudioService.instance.registerAll(clips);
  }
}
