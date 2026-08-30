import 'dart:typed_data';

import 'package:tool_lab/helpers/wav_builder.dart';
import '../chaindrop_audio_service.dart';
import 'chaindrop_engine.dart' show ChainDropSfxKeys;

/// Chain Drop's sound effects, keyed by [ChainDropSfxKeys].
class ChainDropSfx {
  ChainDropSfx._();

  static Future<void> load() async {
    final clips = <String, Uint8List>{
      ChainDropSfxKeys.drop: WavBuilder.tone(
        frequency: 180,
        seconds: 0.09,
        waveform: Waveform.triangle,
        gain: 0.18,
        slideHz: -60,
      ),
      ChainDropSfxKeys.pop: WavBuilder.tone(
        frequency: 660,
        seconds: 0.12,
        waveform: Waveform.square,
        gain: 0.16,
        slideHz: 220,
      ),
      ChainDropSfxKeys.crackHit: WavBuilder.noise(
        seconds: 0.08,
        gain: 0.2,
        highPassHz: 1200,
      ),
      ChainDropSfxKeys.crackBreak: WavBuilder.noise(
        seconds: 0.16,
        gain: 0.25,
        highPassHz: 600,
        decay: 4,
      ),
      ChainDropSfxKeys.garbageRow: WavBuilder.sequence(
        notes: const [
          ToneSpec(
            frequency: 220,
            seconds: 0.12,
            waveform: Waveform.sawtooth,
            gain: 0.16,
          ),
          ToneSpec(
            frequency: 165,
            seconds: 0.16,
            waveform: Waveform.sawtooth,
            gain: 0.16,
          ),
        ],
        gapSeconds: 0.08,
      ),
      ChainDropSfxKeys.gameOver: WavBuilder.sequence(
        notes: const [
          ToneSpec(
            frequency: 330,
            seconds: 0.22,
            waveform: Waveform.sawtooth,
            gain: 0.18,
          ),
          ToneSpec(
            frequency: 247,
            seconds: 0.22,
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
    };
    await ChainDropAudioService.instance.registerAll(clips);
  }
}
