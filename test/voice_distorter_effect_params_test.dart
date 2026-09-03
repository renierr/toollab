import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/tools/voice_distorter/engine/voice_effect.dart';

/// Semitones the playback rate itself shifts everything by.
double _rateSemitones(VoiceEffectParams p) =>
    12 * (math.log(p.playbackRate) / math.ln2);

void main() {
  group('formant shifting', () {
    test('a neutral effect plays back untouched', () {
      const p = VoiceEffectParams();
      expect(p.playbackRate, 1);
      expect(p.filterSemitones, 0);
    });

    test('rate and pitch filter always sum to the requested pitch', () {
      const cases = [
        VoiceEffectParams(pitchSemitones: 9, formantSemitones: 5),
        VoiceEffectParams(pitchSemitones: 6, formantSemitones: -5),
        VoiceEffectParams(pitchSemitones: -14, formantSemitones: -7),
        VoiceEffectParams(pitchSemitones: 0, formantSemitones: 4),
      ];
      for (final p in cases) {
        expect(
          _rateSemitones(p) + p.filterSemitones,
          closeTo(p.pitchSemitones, 1e-9),
          reason: 'pitch ${p.pitchSemitones}, formant ${p.formantSemitones}',
        );
      }
    });

    test('a formant-only shift leaves the pitch filter undoing all of it', () {
      const p = VoiceEffectParams(formantSemitones: -7);
      expect(p.playbackRate, closeTo(0.667, 0.001));
      expect(p.filterSemitones, 7);
    });

    test('stays inside the pitch filter range at the extremes', () {
      const up = VoiceEffectParams(pitchSemitones: 24, formantSemitones: -12);
      const down = VoiceEffectParams(pitchSemitones: -24, formantSemitones: 12);
      expect(up.filterSemitones, 36);
      expect(down.filterSemitones, -36);
    });
  });
}
