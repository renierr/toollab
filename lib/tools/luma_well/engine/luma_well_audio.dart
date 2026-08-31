import 'dart:typed_data';

import 'package:tool_lab/helpers/wav_builder.dart';
import '../luma_well_audio_service.dart';

/// Luma Well's sound effects — calm chimes that match the game's slow pace.
class LumaWellSfx {
  LumaWellSfx._();

  static const String _mergePrefix = 'lw_merge_';
  static const int _mergeVariants = 4;
  static const String stageUp = 'lw_stage_up';
  static const String orbCollected = 'lw_orb_collected';
  static const String powerUse = 'lw_power_use';

  /// The variant for a completed merge: bigger point payouts ring a touch
  /// higher, so a large group reads as more rewarding than a small one.
  static String merge(int points) {
    var step = 0;
    if (points >= 40) step = 1;
    if (points >= 120) step = 2;
    if (points >= 300) step = 3;
    return '$_mergePrefix$step';
  }

  static Future<void> load() async {
    final clips = <String, Uint8List>{
      for (var i = 0; i < _mergeVariants; i++)
        '$_mergePrefix$i': WavBuilder.tone(
          frequency: 380 * (1 + i * 0.25),
          seconds: 0.22,
          gain: 0.22,
          slideHz: 140,
          decay: 4.2,
          attackSeconds: 0.01,
        ),
      stageUp: WavBuilder.sequence(
        notes: const [
          ToneSpec(
            frequency: 440,
            seconds: 0.18,
            waveform: Waveform.triangle,
            gain: 0.2,
          ),
          ToneSpec(
            frequency: 554,
            seconds: 0.18,
            waveform: Waveform.triangle,
            gain: 0.2,
          ),
          ToneSpec(
            frequency: 660,
            seconds: 0.18,
            waveform: Waveform.triangle,
            gain: 0.2,
          ),
          ToneSpec(
            frequency: 880,
            seconds: 0.30,
            waveform: Waveform.triangle,
            gain: 0.22,
          ),
        ],
        gapSeconds: 0.14,
      ),
      orbCollected: WavBuilder.tone(
        frequency: 900,
        seconds: 0.14,
        gain: 0.2,
        slideHz: 220,
        decay: 8,
        attackSeconds: 0.005,
      ),
      powerUse: WavBuilder.noise(
        seconds: 0.28,
        gain: 0.16,
        lowPassHz: 900,
        decay: 3.0,
      ),
    };
    await LumaWellAudioService.instance.registerAll(clips);
  }
}
