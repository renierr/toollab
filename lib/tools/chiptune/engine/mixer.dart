import 'dart:math' as math;
import 'dart:typed_data';

import 'module.dart';

/// Chiptune software mixer (MOD/XM/IT): renders a [WorkletModule] to
/// interleaved stereo PCM via [ChiptuneMixer.render], advancing the song
/// position and emitting row/end callbacks as it plays.

const int _effectArpeggio = 0x00;
const int _effectPortaUp = 0x01;
const int _effectPortaDown = 0x02;
const int _effectTonePorta = 0x03;
const int _effectVibrato = 0x04;
const int _effectTonePortaVol = 0x05;
const int _effectVibratoVol = 0x06;
const int _effectTremolo = 0x07;
const int _effectPanning = 0x08;
const int _effectSampleOffset = 0x09;
const int _effectVolumeSlide = 0x0a;
const int _effectPositionJump = 0x0b;
const int _effectSetVolume = 0x0c;
const int _effectPatternBreak = 0x0d;
const int _effectExtended = 0x0e;
const int _effectSetSpeed = 0x0f;
const int _effectGlobalVolume = 0x10; // G
const int _effectGlobalVolSlide = 0x11; // H
const int _effectEnvelopePos = 0x15; // L
const int _effectPanningSlide = 0x19; // P
const int _effectMultiRetrig = 0x1b; // R
const int _effectTremor = 0x1d;

// IT-specific effect constants (must match it-parser.ts exports)
const int _itEffectSetSpeed = 0x20;
const int _itEffectSetTempo = 0x21;
const int _itEffectFineVolslideUp = 0x22;
const int _itEffectFineVolslideDown = 0x23;
const int _itEffectFinePortaDown = 0x24;
const int _itEffectFinePortaUp = 0x25;
const int _itEffectExtraFinePortaDown = 0x26;
const int _itEffectExtraFinePortaUp = 0x27;
const int _itEffectSetChannelVolume = 0x28;
const int _itEffectChannelVolSlide = 0x29;
const int _itEffectFineVibrato = 0x2a;
const int _itEffectTempoSlide = 0x2b;
const int _itEffectSetFilterCutoff = 0x2c;

const List<int> _sineTable = [
  0,
  24,
  49,
  74,
  97,
  120,
  141,
  161,
  180,
  197,
  212,
  224,
  235,
  244,
  250,
  253,
  255,
  253,
  250,
  244,
  235,
  224,
  212,
  197,
  180,
  161,
  141,
  120,
  97,
  74,
  49,
  24,
];

/// `Math.tanh` does not exist in Dart. (e^{2x}-1)/(e^{2x}+1), with overflow
/// guards.
double _tanh(double x) {
  if (x > 20) return 1.0;
  if (x < -20) return -1.0;
  final e = math.exp(2 * x);
  return (e - 1) / (e + 1);
}

double _getSampleVal(int idx, WorkletInstrumentSample smp) {
  if (smp.data.isEmpty) return 0.0;
  if (smp.loopLength > 2) {
    final loopEnd = smp.loopStart + smp.loopLength;
    if (idx >= loopEnd) {
      idx = smp.loopStart + ((idx - loopEnd) % smp.loopLength);
    } else if (idx < smp.loopStart) {
      idx = loopEnd - 1 - ((smp.loopStart - 1 - idx) % smp.loopLength);
    }
  } else {
    if (idx < 0) idx = 0;
    if (idx >= smp.length) return 0.0;
  }
  return (idx >= 0 && idx < smp.data.length) ? smp.data[idx] : 0.0;
}

double _interpolateCubic(
  double s_1,
  double s0,
  double s1,
  double s2,
  double t,
) {
  final a = -0.5 * s_1 + 1.5 * s0 - 1.5 * s1 + 0.5 * s2;
  final b = s_1 - 2.5 * s0 + 2.0 * s1 - 0.5 * s2;
  final c = -0.5 * s_1 + 0.5 * s1;
  final d = s0;
  return a * t * t * t + b * t * t + c * t + d;
}

/// BackgroundVoice: lightweight voice for IT NNA (New Note Action).
/// When a new note triggers on a channel with NNA != cut, the old playing
/// state is moved here so it continues rendering (with fadeout/envelope).
class BackgroundVoice {
  int sourceChannelIndex;
  int? note;
  WorkletInstrumentSample sample;
  WorkletInstrument? instrument;
  double sampleIndex;
  double sampleSpeed;
  double volume;
  double channelVolume;
  double panning;
  bool keyOn;
  double fadeoutVolume;
  int volumeEnvTick;
  int panningEnvTick;
  double volumeEnvValue;
  double panningEnvValue;
  bool playing;
  ChiptuneMixer globalVolumeRef;

  double outL = 0;
  double outR = 0;
  double lastMixedVolume = 0.0;

  BackgroundVoice(WorkletChannel ch)
    : sourceChannelIndex = ch.channelIndex,
      note = ch.note,
      sample = ch.sample!,
      instrument = ch.instrument,
      sampleIndex = ch.sampleIndex,
      sampleSpeed = ch.sampleSpeed,
      volume = ch.volume,
      channelVolume = ch.channelVolume,
      panning = ch.panning,
      keyOn = ch.keyOn,
      fadeoutVolume = ch.fadeoutVolume,
      volumeEnvTick = ch.volumeEnvTick,
      panningEnvTick = ch.panningEnvTick,
      volumeEnvValue = ch.volumeEnvValue,
      panningEnvValue = ch.panningEnvValue,
      playing = true,
      globalVolumeRef = ch.worklet,
      lastMixedVolume = ch.lastMixedVolume;

  /// Apply NNA action: 1=continue, 2=noteOff (start release), 3=fade
  void applyNNA(int nna) {
    switch (nna) {
      case 1: // Continue: keep playing as-is
        break;
      case 2: // Note Off: start envelope release/fadeout
        keyOn = false;
        break;
      case 3: // Note Fade: immediate fadeout
        keyOn = false;
        if (globalVolumeRef.mod?.type != 'IT') {
          fadeoutVolume = math.min(fadeoutVolume, 16384);
        }
        break;
    }
  }

  void applyDCA(int dca) {
    switch (dca) {
      case 0: // cut
        keyOn = false;
        playing = false;
        volume = 0;
        break;
      case 1: // off
        keyOn = false;
        break;
      case 2: // fade
        keyOn = false;
        if (globalVolumeRef.mod?.type != 'IT') {
          fadeoutVolume = math.min(fadeoutVolume, 16384);
        }
        break;
      default:
        break;
    }
  }

  void performTick() {
    if (!playing) return;

    // Process envelope/fadeout
    if (instrument != null) {
      final isIt = globalVolumeRef.mod?.type == 'IT';

      // IT keeps envelope progression running after key-off (release phase).
      if (instrument!.volumeEnv != null && (keyOn || isIt)) {
        volumeEnvValue = calcEnv(instrument!.volumeEnv!, volumeEnvTick++);
      }
      if (instrument!.panningEnv != null && (keyOn || isIt)) {
        panningEnvValue = calcEnv(instrument!.panningEnv!, panningEnvTick++);
      }

      if (!keyOn) {
        if (instrument!.volumeFadeout != null &&
            instrument!.volumeFadeout! > 0) {
          fadeoutVolume = math.max(
            0,
            fadeoutVolume - instrument!.volumeFadeout!,
          );
          if (fadeoutVolume <= 0) {
            playing = false;
            return;
          }
        } else if (!isIt) {
          // No fadeout defined + key off = stop immediately
          playing = false;
          return;
        }
      }
    }
  }

  double calcEnv(Envelope env, int tick) {
    final points = env.points;
    if (points.isEmpty) return 64;
    if ((env.type & 4) != 0 &&
        env.loopEnd != null &&
        env.loopEnd! < points.length) {
      final loopEndTick = points[env.loopEnd!].tick;
      final loopStartTick =
          (env.loopStart != null && env.loopStart! < points.length)
          ? points[env.loopStart!].tick
          : 0;
      if (tick >= loopEndTick && loopEndTick > loopStartTick) {
        tick =
            loopStartTick +
            ((tick - loopStartTick) % (loopEndTick - loopStartTick + 1));
      }
    }
    if (keyOn &&
        (env.type & 2) != 0 &&
        env.sustainStart != null &&
        env.sustainStart! < points.length) {
      final susStartTick = points[env.sustainStart!].tick;
      final susEndIdx = env.sustainEnd ?? env.sustainStart!;
      final susEndTick = points[math.min(susEndIdx, points.length - 1)].tick;
      if (tick >= susStartTick) {
        if (susEndTick > susStartTick) {
          tick =
              susStartTick +
              ((tick - susStartTick) % (susEndTick - susStartTick + 1));
        } else {
          tick = susStartTick;
        }
      }
    }
    if (tick <= points[0].tick) return points[0].value.toDouble();
    for (int i = 0; i < points.length - 1; i++) {
      if (tick <= points[i + 1].tick) {
        final t =
            (tick - points[i].tick) / (points[i + 1].tick - points[i].tick);
        return points[i].value + (points[i + 1].value - points[i].value) * t;
      }
    }
    return points[points.length - 1].value.toDouble();
  }

  double _readRawSampleValue() {
    final i0 = sampleIndex.floor();
    final frac = sampleIndex - i0;
    final s_1 = _getSampleVal(i0 - 1, sample);
    final s0 = _getSampleVal(i0, sample);
    final s1 = _getSampleVal(i0 + 1, sample);
    final s2 = _getSampleVal(i0 + 2, sample);
    return _interpolateCubic(s_1, s0, s1, s2, frac);
  }

  void nextSample() {
    if (!playing || sample.data.isEmpty) {
      if (lastMixedVolume > 0.001) {
        lastMixedVolume = math.max(0.0, lastMixedVolume - (1.0 / 64.0));
        final raw = _readRawSampleValue();
        sampleIndex += sampleSpeed;
        double effectivePanning = panning;
        final panTheta = (effectivePanning / 255) * (math.pi / 2);
        outL = raw * lastMixedVolume * math.cos(panTheta);
        outR = raw * lastMixedVolume * math.sin(panTheta);
        return;
      }
      outL = 0;
      outR = 0;
      lastMixedVolume = 0.0;
      return;
    }

    if (sample.loopLength > 2) {
      final loopEnd = sample.loopStart + sample.loopLength;
      if (sampleIndex >= loopEnd) {
        sampleIndex =
            sample.loopStart + ((sampleIndex - loopEnd) % sample.loopLength);
      }
    } else if (sampleIndex >= sample.length) {
      playing = false;
      outL = 0;
      outR = 0;
      return;
    }

    final raw = _readRawSampleValue();
    sampleIndex += sampleSpeed;

    double vol =
        (volume / 64) *
        (channelVolume / 64) *
        (globalVolumeRef.globalVolume / 64);
    vol *= globalVolumeRef.mixingVolume / 128;
    if (instrument != null) {
      vol *= (volumeEnvValue / 64) * (fadeoutVolume / 32768);
    }

    if (lastMixedVolume != vol) {
      final diff = vol - lastMixedVolume;
      const double step = 1.0 / 64.0;
      if (diff.abs() < step) {
        lastMixedVolume = vol;
      } else {
        lastMixedVolume += diff.sign * step;
      }
    }

    double effectivePanning = panning;
    if (globalVolumeRef.mod?.type == 'IT' && instrument?.panningEnv != null) {
      final envPan = math.max(0.0, math.min(64.0, panningEnvValue));
      if (envPan < 32) {
        effectivePanning = ((effectivePanning * envPan) / 32).roundToDouble();
      } else if (envPan > 32) {
        effectivePanning =
            (effectivePanning + ((255 - effectivePanning) * (envPan - 32)) / 32)
                .roundToDouble();
      }
    }

    final panTheta = (effectivePanning / 255) * (math.pi / 2);
    outL = raw * lastMixedVolume * math.cos(panTheta);
    outR = raw * lastMixedVolume * math.sin(panTheta);
  }
}

class WorkletChannel {
  ChiptuneMixer worklet;
  int channelIndex;

  WorkletInstrument? instrument;
  WorkletInstrumentSample? sample;
  int? note;

  bool playing = false;
  bool keyOn = false;

  double period = 0;
  double targetPeriod = 0;
  double currentPeriod = 0;

  double volume = 64;
  double channelVolume = 64;
  double panning = 128;
  double baseVolume = 64;

  double sampleIndex = 0;
  double sampleFraction = 0;
  double sampleSpeed = 0;

  double vibratoPhase = 0;
  double vibratoSpeed = 0;
  double vibratoDepth = 0;
  int vibratoWaveform = 0;
  double fineVibratoDepth = 0;
  double autoVibratoPhase = 0;
  int autoVibratoTick = 0;
  int filterCutoff = 127;
  double filterState = 0;

  double tremoloPhase = 0;
  double tremoloSpeed = 0;
  double tremoloDepth = 0;
  int tremoloWaveform = 0;

  double slideSpeed = 0;
  double lastMixedVolume = 0.0;
  double volSlideSpeed = 0;
  double channelVolSlide = 0;
  double tempoSlide = 0;
  double fineSlideSpeed = 0;

  List<int> arpeggioNotes = [];

  int volumeEnvTick = 0;
  int panningEnvTick = 0;
  double volumeEnvValue = 64;
  double panningEnvValue = 32;
  double fadeoutVolume = 32768;

  int retrig = 0;
  int retrigVolOp = 0;
  int lastItRetrig = 0;
  int lastItRetrigVolOp = 0;
  double globalVolSlide = 0;
  double panningSlide = 0;
  int tremorCounter = 0;
  bool tremorOn = false;
  int tremorOnTicks = 0;
  int tremorOffTicks = 0;

  WorkletNote? pendingNote;
  int delayNoteTick = -1;

  double outL = 0;
  double outR = 0;

  WorkletChannel(this.worklet, int index) : channelIndex = index {
    reset();
  }

  double _getWaveValue(int phase, int waveform) {
    final shape = waveform & 0x03;
    final p = phase & 63;

    if (shape == 1) {
      // Ramp: +255 .. -255 over one cycle
      return (255 - p * 8).toDouble();
    }
    if (shape == 2) {
      return p < 32 ? 255 : -255;
    }
    if (shape == 3) {
      // Deterministic pseudo-random shape for IT random waveform.
      final x =
          math.sin((p + 1) * 12.9898 + channelIndex * 78.233) * 43758.5453;
      return (x - x.floor()) * 510 - 255;
    }

    if (p < 32) return _sineTable[p].toDouble();
    return -_sineTable[p - 32].toDouble();
  }

  void reset() {
    playing = false;
    sampleIndex = 0;
    sampleFraction = 0;
    // Preservation: We DO NOT reset this.instrument, this.volume, or this.panning
    // because subsequent notes in a tracker row often omit instrument bytes.
    // Clearing them causes silence after seeking or restarting.
    vibratoPhase = 0;
    tremoloPhase = 0;
    volumeEnvTick = 0;
    panningEnvTick = 0;
  }

  void trigger(WorkletNote note) {
    if (note.instrument == 0 && note.period == 0 && note.note == null) {
      handleEffect(note); // Still parse effects on empty note rows
      return;
    }

    // Handle EDx Note Delay
    int noteDelay = 0;
    if (note.effect == _effectExtended &&
        ((note.effectParam >> 4) & 0x0f) == 0x0d) {
      noteDelay = note.effectParam & 0x0f;
    }

    if (noteDelay > 0 && worklet.tick == 0) {
      pendingNote = note;
      delayNoteTick = noteDelay;
      return;
    }

    processTrigger(note);
  }

  WorkletInstrumentSample? _resolveMappedSample(
    WorkletInstrument? inst,
    int noteValue,
  ) {
    if (inst == null || inst.samples.isEmpty) return null;
    int sIdx = 0;
    if (inst.sampleMap != null && noteValue >= 1 && noteValue <= 120) {
      sIdx = inst.sampleMap![noteValue - 1];
    }
    if (sIdx < 0 || sIdx >= inst.samples.length) return null;
    return inst.samples[sIdx];
  }

  bool _matchesDuplicate(
    int dct,
    int noteValue,
    WorkletInstrumentSample? sample,
    WorkletInstrument? instrument,
    int? curNote,
    WorkletInstrumentSample? curSample,
    WorkletInstrument? curInstrument,
  ) {
    if (dct == 1) return curNote == noteValue;
    if (dct == 2) {
      return sample != null &&
          curSample != null &&
          identical(sample, curSample);
    }
    if (dct == 3) {
      return instrument != null &&
          curInstrument != null &&
          identical(instrument, curInstrument);
    }
    return false;
  }

  void _applyDuplicateAction(int dca) {
    switch (dca) {
      case 0: // cut
        keyOn = false;
        playing = false;
        volume = 0;
        break;
      case 1: // off
        keyOn = false;
        break;
      case 2: // fade
        keyOn = false;
        if (worklet.mod?.type != 'IT') {
          fadeoutVolume = math.min(fadeoutVolume, 16384);
        }
        break;
      default:
        break;
    }
  }

  bool _applyDuplicateChecks(
    int dct,
    int dca,
    int noteValue,
    WorkletInstrumentSample? sample,
    WorkletInstrument? instrument,
  ) {
    bool matchedCurrent = false;

    if (playing &&
        _matchesDuplicate(
          dct,
          noteValue,
          sample,
          instrument,
          note,
          this.sample,
          this.instrument,
        )) {
      matchedCurrent = true;
      _applyDuplicateAction(dca);
    }

    // IT duplicate check acts on the current host channel/voice set, not all channels.
    for (int i = 0; i < worklet.backgroundVoices.length; i++) {
      final bg = worklet.backgroundVoices[i];
      if (!bg.playing || bg.sourceChannelIndex != channelIndex) continue;
      if (_matchesDuplicate(
        dct,
        noteValue,
        sample,
        instrument,
        bg.note,
        bg.sample,
        bg.instrument,
      )) {
        bg.applyDCA(dca);
      }
    }

    return matchedCurrent;
  }

  void processTrigger(WorkletNote note) {
    bool tonePorta =
        note.effect == _effectTonePorta || note.effect == _effectTonePortaVol;
    bool matchedCurrentDuplicate = false;
    final previousInstrument = instrument;

    if (worklet.mod!.type == 'IT' &&
        note.note != null &&
        note.note! >= 1 &&
        note.note! <= 120) {
      final incomingNote = note.note!;
      final incomingInstrument = (note.instrument > 0)
          ? (worklet.mod!.instruments.length >= note.instrument
                ? worklet.mod!.instruments[note.instrument - 1]
                : instrument)
          : instrument;
      final dct = incomingInstrument?.dct ?? 0;
      final dca = incomingInstrument?.dca ?? 0;
      if (dct > 0) {
        final mappedSample = _resolveMappedSample(
          incomingInstrument,
          incomingNote,
        );
        matchedCurrentDuplicate = _applyDuplicateChecks(
          dct,
          dca,
          incomingNote,
          mappedSample,
          incomingInstrument,
        );
      }
    }

    if (note.instrument > 0) {
      final inst = (worklet.mod!.instruments.length >= note.instrument)
          ? worklet.mod!.instruments[note.instrument - 1]
          : null;
      if (inst != null) {
        instrument = inst;
        if (inst.samples.isNotEmpty) {
          baseVolume = inst.samples[0].volume.toDouble();
        }

        // MOD quirk: choosing instrument without note restarts volume but NOT sample position (Sample Swapping)
        // XM quirk: choosing instrument without note resets volume/panning but NOT envelopes/position
        if (note.note == null) {
          volume = baseVolume;
          // MOD files use fixed channel panning; only XM/IT use sample-based panning overrides.
          if (worklet.mod!.type != 'MOD' && inst.samples.isNotEmpty) {
            panning = inst.samples[0].panning.toDouble();
          }
        }

        assignSample(note.note ?? this.note ?? 1);
      }
    }

    if (note.note != null) {
      if (note.note == 97) {
        // KeyOff
        keyOn = false;
        if (worklet.mod!.type == 'MOD') {
          playing = false;
          volume = 0;
        }
      } else if (note.note == 98) {
        // Note Cut: immediate stop
        keyOn = false;
        playing = false;
        volume = 0;
      } else if (note.note == 99) {
        // Note Fade: start fadeout without hard cut
        keyOn = false;
        if (worklet.mod?.type != 'IT') {
          fadeoutVolume = math.min(fadeoutVolume, 16384);
        }
      } else {
        if (tonePorta) {
          targetPeriod = calculatePeriod(note.note ?? 0, note.instrument);
        } else {
          // IT NNA: before killing old note, check if it should continue in background
          if (playing &&
              sample != null &&
              !matchedCurrentDuplicate &&
              worklet.mod!.type == 'IT' &&
              previousInstrument != null &&
              previousInstrument.nna != null &&
              previousInstrument.nna! > 0) {
            worklet.spawnBackgroundVoice(this, previousInstrument.nna!);
          }

          this.note = note.note ?? 0;
          assignSample(note.note ?? 0);
          period = (note.period != 0)
              ? note.period.toDouble()
              : calculatePeriod(note.note ?? 0, note.instrument);
          currentPeriod = period;

          // FT2 quirk: only reset volume if instrument is provided
          if (note.instrument > 0) {
            volume = baseVolume;
          }

          if (worklet.mod!.type == 'IT') {
            if ((vibratoWaveform & 0x04) == 0) vibratoPhase = 0;
            if ((tremoloWaveform & 0x04) == 0) tremoloPhase = 0;
          } else {
            vibratoPhase = 0;
            tremoloPhase = 0;
          }

          sampleIndex = 0;
          sampleFraction = 0;
          keyOn = true;
          volumeEnvTick = 0;
          panningEnvTick = 0;
          volumeEnvValue = 64;
          panningEnvValue = 32;
          fadeoutVolume = 32768;
          autoVibratoPhase = 0;
          autoVibratoTick = 0;
          filterState = 0;
          playing = sample != null && period > 0;
        }
      }
    }

    // Standard volume command
    if (note.volume != null && note.volume! <= 64) {
      volume = note.volume!.toDouble();
    }

    // Handle Volume Column (XM)
    if (note.volumeColumn != null) {
      final vc = note.volumeColumn!;
      if (vc >= 0x10 && vc <= 0x50) {
        volume = (vc - 0x10).toDouble(); // Set volume
      } else if (vc >= 0x60 && vc <= 0x6f) {
        volSlideSpeed = -(vc & 0x0f).toDouble(); // Vol slide down
      } else if (vc >= 0x70 && vc <= 0x7f) {
        volSlideSpeed = (vc & 0x0f).toDouble(); // Vol slide up
      } else if (vc >= 0x80 && vc <= 0x8f) {
        // Fine vol slide down
        if (worklet.tick == 0) volume = math.max(0, volume - (vc & 0x0f));
      } else if (vc >= 0x90 && vc <= 0x9f) {
        // Fine vol slide up
        if (worklet.tick == 0) volume = math.min(64, volume + (vc & 0x0f));
      } else if (vc >= 0xa0 && vc <= 0xaf) {
        vibratoSpeed = ((vc & 0x0f) * 2).toDouble();
      } else if (vc >= 0xb0 && vc <= 0xbf) {
        if ((vc & 0x0f) != 0) vibratoDepth = (vc & 0x0f).toDouble();
      } else if (vc >= 0xc0 && vc <= 0xcf) {
        panning = ((vc & 0x0f) * 16 + 8).toDouble();
      } else if (vc >= 0xd0 && vc <= 0xdf) {
        panningSlide = -(vc & 0x0f).toDouble(); // Pan slide left
      } else if (vc >= 0xe0 && vc <= 0xef) {
        panningSlide = (vc & 0x0f).toDouble(); // Pan slide right
      } else if (vc >= 0xf0 && vc <= 0xff) {
        // Tone porta
        if ((vc & 0x0f) != 0) slideSpeed = ((vc & 0x0f) * 16).toDouble();
        tonePorta = true;
      }
    }

    handleEffect(note);
    if (worklet.mod!.type == 'IT' && (note.itVolumeEffect ?? 0) > 0) {
      applyItSecondaryEffect(
        note.itVolumeEffect ?? 0,
        note.itVolumeEffectParam ?? 0,
        true,
      );
    }
  }

  void applyItSecondaryEffect(int effectId, int param, bool tick0) {
    switch (effectId) {
      case _effectPanning:
        if (tick0) panning = param.toDouble();
        break;
      case _effectVolumeSlide:
        if (tick0) {
          if ((param & 0xf0) != 0) {
            volSlideSpeed = ((param >> 4) & 0x0f).toDouble();
          } else if ((param & 0x0f) != 0) {
            volSlideSpeed = -(param & 0x0f).toDouble();
          }
        }
        break;
      case _effectPortaUp:
        if (tick0 && param > 0) slideSpeed = -param.toDouble();
        break;
      case _effectPortaDown:
        if (tick0 && param > 0) slideSpeed = param.toDouble();
        break;
      case _effectTonePorta:
        if (tick0 && param > 0) slideSpeed = param.toDouble();
        break;
      case _effectVibrato:
        if (tick0 && param > 0) vibratoDepth = (param & 0x0f).toDouble();
        break;
      case _effectExtended:
        if (tick0) {
          final sub = (param >> 4) & 0x0f;
          final subParam = param & 0x0f;
          if (sub == 0x0a) {
            volume = math.min(64, volume + subParam);
          } else if (sub == 0x0b) {
            volume = math.max(0, volume - subParam);
          }
        }
        break;
      default:
        break;
    }
  }

  void assignSample(int noteValue) {
    if (instrument == null) return;
    int sIdx = 0;
    final maxNote = worklet.mod!.type == 'IT' ? 120 : 96;
    if (instrument!.sampleMap != null &&
        noteValue >= 1 &&
        noteValue <= maxNote) {
      sIdx = instrument!.sampleMap![noteValue - 1];
    }
    if (worklet.mod!.type == 'IT' && sIdx < 0) {
      // IT instruments may map notes to "no sample". Do not reuse old sample.
      sample = null;
      playing = false;
      return;
    }
    if (sIdx < 0 || sIdx >= instrument!.samples.length) sIdx = 0;
    sample = instrument!.samples.isNotEmpty
        ? (sIdx < instrument!.samples.length
              ? instrument!.samples[sIdx]
              : instrument!.samples[0])
        : null;
    if (sample != null) {
      // Keep channel volume source aligned with the selected sample, not instrument sample 0.
      baseVolume = sample!.volume.toDouble();
    }
    // Don't overwrite MOD hardcoded panning
    if (sample != null && worklet.mod!.type != 'MOD') {
      panning = sample!.panning.toDouble();
    }
  }

  double calculatePeriod(int noteValue, int instrumentIdx) {
    if (worklet.mod == null) return 0;
    final inst = instrumentIdx > 0
        ? (worklet.mod!.instruments.length >= instrumentIdx
              ? worklet.mod!.instruments[instrumentIdx - 1]
              : null)
        : instrument;
    if (inst == null || inst.samples.isEmpty) return 0;

    int sIdx = 0;
    final maxNote = worklet.mod!.type == 'IT' ? 120 : 96;
    if (inst.sampleMap != null && noteValue >= 1 && noteValue <= maxNote) {
      sIdx = inst.sampleMap![noteValue - 1];
    }
    if (sIdx < 0 || sIdx >= inst.samples.length) sIdx = 0;
    final sample = sIdx < inst.samples.length
        ? inst.samples[sIdx]
        : inst.samples[0];

    if (worklet.mod!.type == 'IT') {
      // Apply IT noteMap translation: the instrument maps input notes to output notes
      if (inst.noteMap != null && noteValue >= 1 && noteValue <= 120) {
        final mappedNote = inst.noteMap![noteValue - 1];
        if (mappedNote >= 0 && mappedNote <= 119) {
          return (mappedNote + 1).toDouble(); // convert 0-based to 1-based
        }
      }
      return noteValue.toDouble();
    }

    final actualNote = noteValue - 1 + (sample.baseNote ?? 0);
    final isXmOrIt = worklet.mod!.type == 'XM' || worklet.mod!.type == 'IT';
    if (isXmOrIt) {
      if (worklet.mod!.linearFrequencies) {
        return 10 * 12 * 16 * 4 - actualNote * 16 * 4 - (sample.finetune) / 2;
      } else {
        const amigaTable = [
          1712,
          1616,
          1525,
          1440,
          1357,
          1281,
          1209,
          1141,
          1077,
          1017,
          961,
          907,
        ];
        int n = actualNote;
        int octave = 0;
        while (n >= 12) {
          n -= 12;
          octave++;
        }
        while (n < 0) {
          n += 12;
          octave--;
        }
        final p = amigaTable[n] / math.pow(2, octave);
        return p * 16;
      }
    }

    const amigaTable = [
      1712,
      1616,
      1525,
      1440,
      1357,
      1281,
      1209,
      1141,
      1077,
      1017,
      961,
      907,
    ];
    int n = noteValue - 1 + (sample.baseNote ?? 0);
    int octave = 0;
    while (n >= 12) {
      n -= 12;
      octave++;
    }
    while (n < 0) {
      n += 12;
      octave--;
    }
    final p = amigaTable[n] / math.pow(2, octave);
    return p.toDouble();
  }

  void handleEffect(WorkletNote note) {
    final isIT = worklet.mod!.type == 'IT';

    if (worklet.tick == 0) {
      // For IT: preserve effect memory — only reset values that get explicitly set.
      // For MOD/XM: reset as before (no effect memory).
      if (!isIT) {
        slideSpeed = 0;
        volSlideSpeed = 0;
        channelVolSlide = 0;
        fineSlideSpeed = 0;
      }
      arpeggioNotes = [];
      retrig = 0;
      globalVolSlide = 0;
      panningSlide = 0;
    }

    final effectId = note.effect;
    final param = note.effectParam;

    switch (effectId) {
      case _effectArpeggio:
        if (param > 0) arpeggioNotes = [0, (param >> 4) & 0x0f, param & 0x0f];
        break;
      case _effectPortaUp:
        if (param > 0 || !isIT) slideSpeed = -param.toDouble();
        break;
      case _effectPortaDown:
        if (param > 0 || !isIT) slideSpeed = param.toDouble();
        break;
      case _effectTonePorta:
        if (param > 0) slideSpeed = param.toDouble();
        // IT: param 0 means use last non-zero slide speed (already preserved)
        break;
      case _effectVibrato:
        if ((param & 0x0f) != 0) vibratoDepth = (param & 0x0f).toDouble();
        if ((param & 0xf0) != 0) {
          vibratoSpeed = (((param >> 4) & 0x0f) * 2).toDouble();
        }
        break;
      case _itEffectFineVibrato:
        if ((param & 0x0f) != 0) fineVibratoDepth = (param & 0x0f).toDouble();
        if ((param & 0xf0) != 0) {
          vibratoSpeed = (((param >> 4) & 0x0f) * 2).toDouble();
        }
        break;
      case _effectTonePortaVol:
        if (param > 0) {
          if ((param & 0xf0) != 0) {
            volSlideSpeed = ((param >> 4) & 0x0f).toDouble();
          } else if ((param & 0x0f) != 0) {
            volSlideSpeed = -(param & 0x0f).toDouble();
          }
        }
        break;
      case _effectVibratoVol:
        if (param > 0) {
          if ((param & 0xf0) != 0) {
            volSlideSpeed = ((param >> 4) & 0x0f).toDouble();
          } else if ((param & 0x0f) != 0) {
            volSlideSpeed = -(param & 0x0f).toDouble();
          }
        }
        break;
      case _effectTremolo:
        if ((param & 0x0f) != 0) tremoloDepth = (param & 0x0f).toDouble();
        if ((param & 0xf0) != 0) {
          tremoloSpeed = (((param >> 4) & 0x0f) * 2).toDouble();
        }
        break;
      case _effectPanning:
        panning = param.toDouble();
        break;
      case _effectSampleOffset:
        sampleIndex = (param * 256).toDouble();
        break;
      case _effectPositionJump:
        worklet.setPatternJump(param);
        break;
      case _effectVolumeSlide:
        if (param > 0 || !isIT) {
          if ((param & 0xf0) != 0) {
            volSlideSpeed = ((param >> 4) & 0x0f).toDouble();
          } else if ((param & 0x0f) != 0) {
            volSlideSpeed = -(param & 0x0f).toDouble();
          }
        }
        // IT: param 0 means use last non-zero volSlideSpeed (already preserved)
        break;
      case _effectSetVolume:
        volume = math.min(64, param).toDouble();
        break;
      case _effectPatternBreak:
        // IT uses hex param (already translated); XM uses hex too; only MOD uses BCD
        if (worklet.mod!.type == 'MOD') {
          worklet.setPatternBreak(((param >> 4) & 0x0f) * 10 + (param & 0x0f));
        } else {
          worklet.setPatternBreak(param);
        }
        break;
      case _effectSetSpeed:
        if (param >= 1 && param < 32) {
          worklet.setTicksPerRow(param);
        } else if (param >= 32) {
          worklet.setBpm(param);
        }
        break;
      // IT-specific: Axx always sets speed, Txx always sets tempo
      case _itEffectSetSpeed:
        if (param >= 1) worklet.setTicksPerRow(param);
        break;
      case _itEffectSetTempo:
        if (param >= 32) worklet.setBpm(param);
        break;
      case _itEffectTempoSlide:
        {
          final hi = (param >> 4) & 0x0f;
          final lo = param & 0x0f;
          if (hi > 0 && lo == 0) {
            tempoSlide = hi.toDouble();
          } else if (lo > 0 && hi == 0) {
            tempoSlide = -lo.toDouble();
          }
        }
        break;
      // IT-specific fine volume slides (tick 0 only)
      case _itEffectFineVolslideUp:
        if (worklet.tick == 0) volume = math.min(64, volume + param);
        break;
      case _itEffectFineVolslideDown:
        if (worklet.tick == 0) volume = math.max(0, volume - param);
        break;
      // IT-specific fine/extra-fine portamento (tick 0 only)
      case _itEffectFinePortaDown:
        if (worklet.tick == 0) currentPeriod += param / 64;
        break;
      case _itEffectFinePortaUp:
        if (worklet.tick == 0) currentPeriod -= param / 64;
        break;
      case _itEffectExtraFinePortaDown:
        if (worklet.tick == 0) currentPeriod += param / 256;
        break;
      case _itEffectExtraFinePortaUp:
        if (worklet.tick == 0) currentPeriod -= param / 256;
        break;
      case _itEffectSetChannelVolume:
        channelVolume = math.max(0, math.min(64, param)).toDouble();
        break;
      case _itEffectChannelVolSlide:
        if (param > 0 || !isIT) {
          if ((param & 0xf0) != 0) {
            channelVolSlide = ((param >> 4) & 0x0f).toDouble();
          } else if ((param & 0x0f) != 0) {
            channelVolSlide = -(param & 0x0f).toDouble();
          }
        }
        break;
      case _itEffectSetFilterCutoff:
        if (worklet.mod!.type == 'IT') {
          filterCutoff = math.max(0, math.min(127, param));
        }
        break;
      case _effectGlobalVolume:
        worklet.globalVolume = math.min(64, param);
        break;
      case _effectGlobalVolSlide:
        if (param > 0) {
          if ((param & 0xf0) != 0) {
            globalVolSlide = (param >> 4).toDouble();
          } else if ((param & 0x0f) != 0) {
            globalVolSlide = -(param & 0x0f).toDouble();
          }
        }
        break;
      case _effectPanningSlide:
        if (param > 0) {
          if ((param & 0xf0) != 0) {
            panningSlide = (param >> 4).toDouble();
          } else if ((param & 0x0f) != 0) {
            panningSlide = -(param & 0x0f).toDouble();
          }
        }
        break;
      case _effectMultiRetrig:
        if (isIT) {
          if ((param & 0x0f) != 0) lastItRetrig = param & 0x0f;
          if ((param & 0xf0) != 0) lastItRetrigVolOp = (param >> 4) & 0x0f;
          retrig = lastItRetrig;
          retrigVolOp = lastItRetrigVolOp;
        } else {
          if ((param & 0x0f) != 0) retrig = param & 0x0f;
          if ((param & 0xf0) != 0) retrigVolOp = (param >> 4) & 0x0f;
        }
        break;
      case _effectTremor:
        if (param > 0) {
          tremorOn = true;
          tremorCounter = 0;
          tremorOnTicks = ((param >> 4) & 0x0f) + 1;
          tremorOffTicks = (param & 0x0f) + 1;
        }
        break;
      case _effectEnvelopePos:
        volumeEnvTick = param;
        panningEnvTick = param;
        break;
      case _effectExtended:
        final sub = (param >> 4) & 0x0f;
        final subParam = param & 0x0f;
        switch (sub) {
          case 0x0:
            if (worklet.mod!.type == 'MOD') {
              worklet.amigaFilter = (subParam == 0);
            }
            break;
          case 0x1:
            if (isIT) {
              currentPeriod -= subParam / 64;
            } else if (worklet.mod!.type == 'XM') {
              currentPeriod -= (subParam * 4).toDouble();
            } else {
              currentPeriod -= subParam.toDouble();
            }
            break;
          case 0x2:
            if (isIT) {
              currentPeriod += subParam / 64;
            } else if (worklet.mod!.type == 'XM') {
              currentPeriod += (subParam * 4).toDouble();
            } else {
              currentPeriod += subParam.toDouble();
            }
            break;
          case 0x4:
            vibratoWaveform = isIT ? subParam : subParam & 3;
            break;
          case 0x5:
            worklet.setPatternLoopStart();
            break;
          case 0x6:
            if (subParam == 0) {
              worklet.setPatternLoopStart();
            } else {
              worklet.handlePatternLoop(subParam);
            }
            break;
          case 0x7:
            tremoloWaveform = isIT ? subParam : subParam & 3;
            break;
          case 0x9:
            retrig = subParam;
            break;
          case 0xa:
            volume = math.min(64, volume + subParam);
            break;
          case 0xb:
            volume = math.max(0, volume - subParam);
            break;
          case 0xc:
            if (worklet.tick == subParam) {
              if (isIT) {
                keyOn = false;
                playing = false;
                volume = 0;
              } else {
                volume = 0;
              }
            }
            break;
          case 0xe:
            worklet.setPatternDelay(subParam);
            break;
        }
        break;
    }
  }

  void performTick() {
    if (delayNoteTick != -1) {
      if (worklet.tick == delayNoteTick) {
        if (pendingNote != null) processTrigger(pendingNote!);
        delayNoteTick = -1;
        pendingNote = null;
      }
    }

    if (!playing) return;

    if (worklet.tick > 0) {
      if (volSlideSpeed != 0) {
        volume = math.max(0, math.min(64, volume + volSlideSpeed));
      }
      if (channelVolSlide != 0) {
        channelVolume = math.max(
          0,
          math.min(64, channelVolume + channelVolSlide),
        );
      }
      final rowEffect = (channelIndex < worklet.currentRowNotes.length)
          ? worklet.currentRowNotes[channelIndex].effect
          : null;
      if (tempoSlide != 0 &&
          worklet.mod!.type == 'IT' &&
          rowEffect == _itEffectTempoSlide) {
        worklet.setBpm(
          math.max(32, math.min(255, worklet.bpm + tempoSlide)).toInt(),
        );
      }
      if (globalVolSlide != 0) {
        worklet.globalVolume = math
            .max(0, math.min(64, worklet.globalVolume + globalVolSlide))
            .toInt();
      }
      if (panningSlide != 0) {
        panning = math.max(0, math.min(255, panning + panningSlide));
      }

      final effect = (channelIndex < worklet.currentRowNotes.length)
          ? worklet.currentRowNotes[channelIndex].effect
          : null;
      if (effect == _effectTonePorta || effect == _effectTonePortaVol) {
        if (worklet.mod!.type == 'IT') {
          // IT: period is note number; slide in fractional note units (param/64 semitones per tick)
          final slideAmt = slideSpeed / 64;
          if (targetPeriod != 0) {
            if (currentPeriod < targetPeriod) {
              currentPeriod = math.min(currentPeriod + slideAmt, targetPeriod);
            } else {
              currentPeriod = math.max(currentPeriod - slideAmt, targetPeriod);
            }
          }
        } else if (worklet.mod!.type == 'XM') {
          if (targetPeriod != 0) {
            if (currentPeriod < targetPeriod) {
              currentPeriod = math.min(
                currentPeriod + slideSpeed * 4,
                targetPeriod,
              );
            } else {
              currentPeriod = math.max(
                currentPeriod - slideSpeed * 4,
                targetPeriod,
              );
            }
          } else if (slideSpeed != 0) {
            currentPeriod += slideSpeed * 4;
          }
        } else {
          // MOD standard periods
          if (targetPeriod != 0) {
            if (currentPeriod < targetPeriod) {
              currentPeriod = math.min(
                currentPeriod + slideSpeed,
                targetPeriod,
              );
            } else {
              currentPeriod = math.max(
                currentPeriod - slideSpeed,
                targetPeriod,
              );
            }
          } else if (slideSpeed != 0) {
            currentPeriod += slideSpeed;
          }
        }
      } else if (slideSpeed != 0) {
        if (worklet.mod!.type == 'IT') {
          // IT: slide in fractional note units (param/64 semitones per tick)
          currentPeriod += slideSpeed / 64;
        } else if (worklet.mod!.type == 'XM') {
          currentPeriod += slideSpeed * 4;
        } else {
          currentPeriod += slideSpeed;
        }
      }

      if (retrig > 0 && worklet.tick % retrig == 0) {
        _applyRetrigVolumeOp();
        sampleIndex = 0;
        sampleFraction = 0;
      }

      final volEffect = (channelIndex < worklet.currentRowNotes.length)
          ? (worklet.currentRowNotes[channelIndex].itVolumeEffect ?? 0)
          : 0;
      final volParam = (channelIndex < worklet.currentRowNotes.length)
          ? (worklet.currentRowNotes[channelIndex].itVolumeEffectParam ?? 0)
          : 0;
      if (worklet.mod!.type == 'IT' && volEffect > 0) {
        applyItSecondaryEffect(volEffect, volParam, false);
      }

      if (tremorOn) {
        final onTicks = math.max(1, tremorOnTicks);
        final offTicks = math.max(1, tremorOffTicks);
        final cycleLen = onTicks + offTicks;
        tremorCounter++;
        if (tremorCounter >= cycleLen) tremorCounter = 0;
      }

      if (worklet.mod!.type == 'IT' && tremoloDepth > 0) {
        tremoloPhase += tremoloSpeed / 256;
      }
    }

    if (instrument != null) {
      final isIt = worklet.mod!.type == 'IT';

      // IT continues envelope progression during release; MOD/XM keep existing behavior.
      if (instrument!.volumeEnv != null && (keyOn || isIt)) {
        volumeEnvValue = calculateEnvelope(
          instrument!.volumeEnv!,
          volumeEnvTick++,
        );
      }
      if (instrument!.panningEnv != null && (keyOn || isIt)) {
        panningEnvValue = calculateEnvelope(
          instrument!.panningEnv!,
          panningEnvTick++,
        );
      }

      if (!keyOn) {
        if (instrument!.volumeFadeout != null &&
            instrument!.volumeFadeout! > 0) {
          fadeoutVolume = math.max(
            0,
            fadeoutVolume - instrument!.volumeFadeout!,
          );
          if (fadeoutVolume <= 0) playing = false;
        } else if (!isIt) {
          playing = false;
        }
      }
    }

    double renderPeriod = currentPeriod;

    // Arpeggio logic
    if (arpeggioNotes.isNotEmpty) {
      final isXmOrIt = worklet.mod!.type == 'XM' || worklet.mod!.type == 'IT';
      final isIT = worklet.mod!.type == 'IT';

      // ProTracker Arpeggio Quirk: Does not play on Tick 0
      if (!isXmOrIt && worklet.tick % worklet.ticksPerRow == 0) {
        // Stay on base note
      } else {
        final cycle = worklet.tick % 3;
        int arpNote = 0;
        if (isXmOrIt) {
          // FT2/IT Arpeggio cycle: 0, y, x
          if (cycle == 0) {
            arpNote = 0;
          } else if (cycle == 1) {
            arpNote = arpeggioNotes[1]; // low nibble
          } else {
            arpNote = arpeggioNotes[2]; // high nibble
          }
        } else {
          arpNote = arpeggioNotes[cycle];
        }

        if (arpNote > 0) {
          if (isIT) {
            // IT: period is note number, just add semitones directly
            renderPeriod += arpNote;
          } else if (worklet.mod!.type == 'XM') {
            if (worklet.mod!.linearFrequencies) {
              renderPeriod -= (arpNote * 16 * 4).toDouble();
            } else {
              renderPeriod /= math.pow(2, arpNote / 12);
            }
          } else {
            renderPeriod /= math.pow(2, arpNote / 12);
          }
        }
      }
    }

    final isFineVibratoRow =
        (channelIndex < worklet.currentRowNotes.length) &&
        worklet.currentRowNotes[channelIndex].effect == _itEffectFineVibrato;
    final activeVibratoDepth = isFineVibratoRow
        ? fineVibratoDepth / 4
        : vibratoDepth;

    if (activeVibratoDepth > 0) {
      final phase = (vibratoPhase * 64).floor() & 63;
      final modValue = _getWaveValue(phase, vibratoWaveform);

      final isIT = worklet.mod!.type == 'IT';

      if (isIT) {
        // IT: period is note number, vibrato adds fractional semitones
        renderPeriod += (modValue * activeVibratoDepth) / (128 * 16);
      } else {
        final isXm = worklet.mod!.type == 'XM';
        final depthScale = isXm && worklet.mod!.linearFrequencies ? 4 : 1;

        if (worklet.mod!.linearFrequencies) {
          renderPeriod += (modValue * activeVibratoDepth * depthScale) / 128;
        } else {
          renderPeriod +=
              (modValue * activeVibratoDepth * depthScale * 4) / 128;
        }
      }

      vibratoPhase += vibratoSpeed / 256;
    }

    // IT sample auto-vibrato (from IMPS header), IT-only.
    if (worklet.mod!.type == 'IT' &&
        sample != null &&
        (sample!.vibratoDepth ?? 0) > 0) {
      final rawDepth = (sample!.vibratoDepth ?? 0) / 64;
      double depth = rawDepth;
      final sweep = sample!.vibratoSweep ?? 0;
      if (sweep > 0) {
        depth *= math.min(1, autoVibratoTick / sweep);
      }

      final waveform = (sample!.vibratoType ?? 0) & 0x03;
      final phase = autoVibratoPhase - autoVibratoPhase.floor();
      double wave = 0;
      if (waveform == 1) {
        wave = 1 - phase * 2;
      } else if (waveform == 2) {
        wave = phase < 0.5 ? 1 : -1;
      } else if (waveform == 3) {
        wave = math.sin(autoVibratoTick * 12.9898) * 0.5;
      } else {
        wave = math.sin(phase * math.pi * 2);
      }

      renderPeriod += wave * depth;
      autoVibratoPhase += (sample!.vibratoRate ?? 0) / 256;
      autoVibratoTick++;
    }

    final freq = getFrequency(renderPeriod);
    sampleSpeed = freq / worklet.sampleRate;
  }

  double calculateEnvelope(Envelope env, int tick) {
    final points = env.points;
    if (points.isNotEmpty) {
      if ((env.type & 4) != 0 &&
          env.loopEnd != null &&
          env.loopEnd! < points.length) {
        final loopEndTick = points[env.loopEnd!].tick;
        final loopStartTick =
            (env.loopStart != null && env.loopStart! < points.length)
            ? points[env.loopStart!].tick
            : 0;
        if (tick >= loopEndTick) {
          tick =
              loopStartTick +
              ((tick - loopStartTick) % (loopEndTick - loopStartTick + 1));
        }
      }
      if (keyOn &&
          (env.type & 2) != 0 &&
          env.sustainStart != null &&
          env.sustainStart! < points.length) {
        final susStartTick = points[env.sustainStart!].tick;
        final susEndIdx = env.sustainEnd ?? env.sustainStart!;
        final susEndTick = points[math.min(susEndIdx, points.length - 1)].tick;
        if (tick >= susStartTick) {
          if (susEndTick > susStartTick) {
            tick =
                susStartTick +
                ((tick - susStartTick) % (susEndTick - susStartTick + 1));
          } else {
            tick = susStartTick;
          }
        }
      }

      if (tick <= points[0].tick) return points[0].value.toDouble();
      for (int i = 0; i < points.length - 1; i++) {
        if (tick <= points[i + 1].tick) {
          final t =
              (tick - points[i].tick) / (points[i + 1].tick - points[i].tick);
          return points[i].value + (points[i + 1].value - points[i].value) * t;
        }
      }
      return points[points.length - 1].value.toDouble();
    }
    return 64;
  }

  double getFrequency(double period) {
    if (period <= 0) return 0;
    if (worklet.mod!.type == 'IT') {
      // IT: period IS the note number (1-120). C-5 = note 61.
      // Frequency = C5Speed * 2^((note - 61) / 12)
      final semitoneFromC5 = period - 61;
      return (sample?.c5speed ?? 8363) * math.pow(2, semitoneFromC5 / 12)
          as double;
    }
    if (worklet.mod!.linearFrequencies) {
      return 8363 * math.pow(2, (4608 - period) / 768) as double;
    }
    final ft = sample != null ? sample!.finetune : 0;
    final isXmOrIt = worklet.mod!.type == 'XM' || worklet.mod!.type == 'IT';
    if (isXmOrIt) {
      period *= math.pow(2, -ft / (128 * 12));
      return worklet.mod!.clock / ((period * 2) / 16);
    } else {
      period *= math.pow(2, -ft / (8 * 12));
      return worklet.mod!.clock / (period * 2);
    }
  }

  void nextSample() {
    if (!playing || sample == null || sample!.data.isEmpty) {
      if (lastMixedVolume > 0.001) {
        lastMixedVolume = math.max(0.0, lastMixedVolume - (1.0 / 64.0));
        final raw = 0.0;
        final panTheta = (panning / 255) * (math.pi / 2);
        outL = raw * lastMixedVolume * math.cos(panTheta);
        outR = raw * lastMixedVolume * math.sin(panTheta);
        return;
      }
      outL = 0;
      outR = 0;
      lastMixedVolume = 0.0;
      return;
    }
    final smp = sample!;
    if (smp.loopLength > 2) {
      final loopEnd = smp.loopStart + smp.loopLength;
      if (sampleIndex >= loopEnd) {
        sampleIndex =
            smp.loopStart + ((sampleIndex - loopEnd) % smp.loopLength);
      }
    } else if (sampleIndex >= smp.length) {
      playing = false;
      outL = 0;
      outR = 0;
      return;
    }
    final i0 = sampleIndex.floor();
    final frac = sampleIndex - i0;

    final s_1 = _getSampleVal(i0 - 1, smp);
    final s0 = _getSampleVal(i0, smp);
    final s1 = _getSampleVal(i0 + 1, smp);
    final s2 = _getSampleVal(i0 + 2, smp);

    double raw = _interpolateCubic(s_1, s0, s1, s2, frac);

    if (worklet.mod!.type == 'IT' && filterCutoff < 127) {
      final normalized = filterCutoff / 127;
      final alpha = math.max(0.01, normalized * normalized * 0.6);
      filterState += alpha * (raw - filterState);
      raw = filterState;
    }

    sampleIndex += sampleSpeed;
    double vol =
        (volume / 64) * (channelVolume / 64) * (worklet.globalVolume / 64);
    vol *= worklet.mixingVolume / 128;
    if (tremorOn) {
      final onTicks = math.max(1, tremorOnTicks);
      if (tremorCounter >= onTicks) vol = 0;
    }

    if (worklet.mod!.type == 'IT' && tremoloDepth > 0) {
      final phase = (tremoloPhase * 64).floor() & 63;
      final tremoloMod = _getWaveValue(phase, tremoloWaveform);
      vol *= 1 + (tremoloMod * tremoloDepth) / (128 * 64);
    }

    if (instrument != null) {
      vol *= (volumeEnvValue / 64) * (fadeoutVolume / 32768);
    }

    if (lastMixedVolume != vol) {
      final diff = vol - lastMixedVolume;
      const double step = 1.0 / 64.0;
      if (diff.abs() < step) {
        lastMixedVolume = vol;
      } else {
        lastMixedVolume += diff.sign * step;
      }
    }

    double effectivePanning = panning;
    if (worklet.mod!.type == 'IT' && instrument?.panningEnv != null) {
      final envPan = math.max(0.0, math.min(64.0, panningEnvValue));
      if (envPan < 32) {
        effectivePanning = ((effectivePanning * envPan) / 32).roundToDouble();
      } else if (envPan > 32) {
        effectivePanning =
            (effectivePanning + ((255 - effectivePanning) * (envPan - 32)) / 32)
                .roundToDouble();
      }
    }

    final panTheta = (effectivePanning / 255) * (math.pi / 2);
    outL = raw * lastMixedVolume * math.cos(panTheta);
    outR = raw * lastMixedVolume * math.sin(panTheta);
  }

  void _applyRetrigVolumeOp() {
    switch (retrigVolOp) {
      case 0x1:
        volume -= 1;
        break;
      case 0x2:
        volume -= 2;
        break;
      case 0x3:
        volume -= 4;
        break;
      case 0x4:
        volume -= 8;
        break;
      case 0x5:
        volume -= 16;
        break;
      case 0x6:
        volume = ((volume * 2) / 3).floorToDouble();
        break;
      case 0x7:
        volume = (volume / 2).floorToDouble();
        break;
      case 0x9:
        volume += 1;
        break;
      case 0xa:
        volume += 2;
        break;
      case 0xb:
        volume += 4;
        break;
      case 0xc:
        volume += 8;
        break;
      case 0xd:
        volume += 16;
        break;
      case 0xe:
        volume = ((volume * 3) / 2).floorToDouble();
        break;
      case 0xf:
        volume *= 2;
        break;
      default:
        break;
    }
    volume = math.max(0, math.min(64, volume));
  }
}

class ChiptuneMixer {
  WorkletModule? mod;
  List<WorkletChannel> channels = [];
  List<BackgroundVoice> backgroundVoices = [];
  static const int maxBackgroundVoices = 64;
  bool playing = false;
  int sampleRate = 44100;
  int tick = 0;
  int ticksPerRow = 6;
  int bpm = 125;
  int position = 0;
  int rowIndex = 0;
  double outputsPerTick = 0;
  double outputsUntilNextTick = 0;
  int globalVolume = 64;
  int mixingVolume = 128;
  double masterVolume = 0.7;
  int patternLoopRow = -1;
  int patternLoopCount = 0;
  int patternLoopPosition = -1;
  bool loopJumpPending = false;
  int jumpPosition = -1;
  int jumpRowIndex = -1;
  int patternDelay = 0;
  bool isLooping = true;
  List<WorkletNote> currentRowNotes = [];

  bool amigaFilter = false;
  double stereoWidth = 1.0;
  double _fLx1 = 0, _fLx2 = 0, _fLy1 = 0, _fLy2 = 0;
  double _fRx1 = 0, _fRx2 = 0, _fRy1 = 0, _fRy2 = 0;

  double _applyAmigaFilterL(double x) {
    final y =
        0.03913 * x +
        0.07826 * _fLx1 +
        0.03913 * _fLx2 -
        (-1.43834) * _fLy1 -
        0.59486 * _fLy2;
    _fLx2 = _fLx1;
    _fLx1 = x;
    _fLy2 = _fLy1;
    _fLy1 = y;
    return y;
  }

  double _applyAmigaFilterR(double x) {
    final y =
        0.03913 * x +
        0.07826 * _fRx1 +
        0.03913 * _fRx2 -
        (-1.43834) * _fRy1 -
        0.59486 * _fRy2;
    _fRx2 = _fRx1;
    _fRx1 = x;
    _fRy2 = _fRy1;
    _fRy1 = y;
    return y;
  }

  // Callbacks replacing port.postMessage.
  void Function(
    int position,
    int rowIndex,
    List<bool> activeChannels,
    List<int> channelInstruments,
  )?
  onRow;
  void Function()? onEnded;

  // ---- Public control API (replaces port.onmessage branches) ----

  /// 'play' branch.
  void loadAndPlay(WorkletModule mod, int sampleRate, {bool looping = true}) {
    this.mod = mod;
    this.sampleRate = sampleRate;
    isLooping = looping != false;
    globalVolume = mod.globalVolume;
    mixingVolume = mod.mixingVolume;
    setBpm(mod.defaultBpm != 0 ? mod.defaultBpm : 125);
    setTicksPerRow(mod.defaultSpeed != 0 ? mod.defaultSpeed : 6);
    _fLx1 = _fLx2 = _fLy1 = _fLy2 = 0;
    _fRx1 = _fRx2 = _fRy1 = _fRy2 = 0;
    amigaFilter = false;
    channels = [];
    for (int i = 0; i < mod.channels; i++) {
      final ch = WorkletChannel(this, i);
      // Standard Amiga panning: LRRL (Channels 0, 3 Left-ish; 1, 2 Right-ish)
      if (mod.type == 'MOD') {
        ch.panning = (i % 4 == 1 || i % 4 == 2) ? 200 : 56;
      } else if (mod.channelPanning != null && i < mod.channelPanning!.length) {
        ch.panning = mod.channelPanning![i].toDouble();
      }

      if (mod.channelVolumes != null && i < mod.channelVolumes!.length) {
        ch.channelVolume = mod.channelVolumes![i].toDouble();
      }
      channels.add(ch);
    }
    position = mod.restartPosition;
    rowIndex = -1;
    tick = ticksPerRow; // Force immediate Row 0 trigger on first process sample
    // Reset sequencing state so nothing carries over from a previous song.
    jumpPosition = -1;
    jumpRowIndex = -1;
    patternLoopRow = -1;
    patternLoopCount = 0;
    patternLoopPosition = -1;
    loopJumpPending = false;
    patternDelay = 0;
    backgroundVoices = [];
    playing = true;
  }

  /// 'stop' branch.
  void stop() {
    playing = false;
    // Optional: clear active channel output to avoid buzzing
    for (final ch in channels) {
      ch.playing = false;
    }
    backgroundVoices = [];
  }

  /// 'resume' branch.
  void resume() {
    playing = true;
    for (final ch in channels) {
      if (ch.sample != null) ch.playing = true;
    }
  }

  /// 'seek' branch.
  void seek(int position, int rowIndex) {
    final int len = mod?.length ?? 0;
    if (len > 0) position = position.clamp(0, len - 1);
    this.position = position;
    this.rowIndex = rowIndex - 1;
    tick = ticksPerRow;
    // Drop any pending jump / pattern-loop state from before the seek.
    jumpPosition = -1;
    jumpRowIndex = -1;
    loopJumpPending = false;
    patternLoopRow = -1;
    patternLoopCount = 0;
    for (final ch in channels) {
      ch.reset();
    }
    backgroundVoices = [];
  }

  /// 'setVolume' branch.
  void setMasterVolume(double v) {
    masterVolume = v;
  }

  /// 'setSpeed' branch.
  void setSpeed(int speed) {
    setTicksPerRow(speed);
  }

  /// 'setLooping' branch.
  void setLooping(bool looping) {
    isLooping = looping != false;
  }

  // ---- Internal timing/sequencing ----

  void setTicksPerRow(int tpr) {
    ticksPerRow = tpr != 0 ? tpr : 6;
  }

  void setBpm(int bpm) {
    this.bpm = bpm != 0 ? bpm : 125;
    outputsPerTick = (sampleRate * 2.5) / this.bpm;
  }

  void setPatternBreak(int row) {
    jumpRowIndex = row;
    if (jumpPosition == -1) jumpPosition = position + 1;
  }

  void setPatternJump(int pos) {
    jumpPosition = pos;
    jumpRowIndex = 0;
  }

  void setPatternLoopStart() {
    patternLoopRow = rowIndex;
    patternLoopPosition = position;
  }

  /// Standard E6x pattern-loop counting. The first encounter arms the counter
  /// and jumps back; subsequent encounters decrement until it expires. The
  /// counter must NOT be re-initialised on the looped-back re-trigger, or the
  /// loop never ends (the cause of some modules playing forever).
  void handlePatternLoop(int count) {
    if (patternLoopRow < 0) return; // no loop start seen yet
    if (patternLoopCount > 0) {
      patternLoopCount--;
      if (patternLoopCount > 0) loopJumpPending = true;
    } else {
      patternLoopCount = count;
      loopJumpPending = true;
    }
  }

  void setPatternDelay(int frames) {
    patternDelay = frames;
  }

  /// Spawn a background voice from a channel's current playing state (IT NNA)
  void spawnBackgroundVoice(WorkletChannel ch, int nna) {
    if (ch.sample == null || !ch.playing) return;
    // Limit background voices to prevent CPU overload
    if (backgroundVoices.length >= maxBackgroundVoices) {
      // Remove the oldest/quietest voice
      int minIdx = 0;
      double minVol = double.infinity;
      for (int i = 0; i < backgroundVoices.length; i++) {
        final v =
            backgroundVoices[i].volume * backgroundVoices[i].fadeoutVolume;
        if (v < minVol) {
          minVol = v;
          minIdx = i;
        }
      }
      backgroundVoices.removeAt(minIdx);
    }
    final bg = BackgroundVoice(ch);
    bg.applyNNA(nna);
    backgroundVoices.add(bg);
  }

  void nextRow() {
    // Once playback has ended, do not advance again — the order list has been
    // exhausted and indexing it would be out of range.
    if (!playing || mod == null) return;
    if (patternDelay > 0) {
      patternDelay--;
      return;
    }
    final previousPosition = position;
    if (loopJumpPending) {
      rowIndex = patternLoopRow;
      position = patternLoopPosition;
      loopJumpPending = false;
    } else if (jumpPosition != -1) {
      if (!isLooping && jumpPosition <= previousPosition) {
        playing = false;
        onEnded?.call();
        jumpPosition = -1;
        jumpRowIndex = -1;
        return;
      }
      position = jumpPosition;
      rowIndex = jumpRowIndex != -1 ? jumpRowIndex : 0;
      jumpPosition = -1;
      jumpRowIndex = -1;
    } else {
      rowIndex++;
      final curPatIdx = mod!.patternTable[position];
      final curPat = (curPatIdx >= 0 && curPatIdx < mod!.patterns.length)
          ? mod!.patterns[curPatIdx]
          : null;
      if (curPat != null && rowIndex >= curPat.rows.length) {
        rowIndex = 0;
        position++;
      }
    }
    if (position >= mod!.length || position < 0) {
      if (!isLooping) {
        playing = false;
        onEnded?.call();
        return;
      }
      position = mod!.restartPosition;
    }
    final patIdx = mod!.patternTable[position];
    final pat = (patIdx >= 0 && patIdx < mod!.patterns.length)
        ? mod!.patterns[patIdx]
        : null;
    if (pat != null) {
      currentRowNotes = pat.rows[rowIndex].notes;
      for (int i = 0; i < channels.length; i++) {
        final ch = channels[i];
        // For MOD/XM: reset row-specific slide memory before processing new row/note
        // For IT: preserve effect memory (reset is handled in handleEffect)
        if (mod!.type != 'IT') {
          ch.volSlideSpeed = 0;
          ch.panningSlide = 0;
          ch.vibratoDepth =
              0; // Standard trackers reset these unless re-triggered
        }

        if (i < currentRowNotes.length) ch.trigger(currentRowNotes[i]);
      }
    }
    final activeChannels = channels
        .map((ch) => ch.playing && ch.volume > 0)
        .toList();
    final channelInstruments = channels
        .map((ch) => ch.instrument?.index ?? 0)
        .toList();
    onRow?.call(position, rowIndex, activeChannels, channelInstruments);
  }

  /// Replaces process(_inputs, outputs). [out] is INTERLEAVED stereo of length
  /// [frames]*2 (out[2*i]=left, out[2*i+1]=right).
  void render(Float32List out, int frames) {
    if (!playing || mod == null) {
      for (int i = 0; i < frames * 2; i++) {
        out[i] = 0.0;
      }
      return;
    }

    for (int i = 0; i < frames; i++) {
      if (outputsUntilNextTick <= 0) {
        tick++;
        if (tick >= ticksPerRow) {
          tick = 0;
          nextRow();
        }
        for (final ch in channels) {
          ch.performTick();
        }
        // Tick background voices (IT NNA)
        for (int bg = backgroundVoices.length - 1; bg >= 0; bg--) {
          backgroundVoices[bg].performTick();
          if (!backgroundVoices[bg].playing) {
            backgroundVoices.removeAt(bg);
          }
        }
        outputsUntilNextTick += outputsPerTick;
      }
      outputsUntilNextTick--;

      double lOut = 0;
      double rOut = 0;
      for (final ch in channels) {
        ch.nextSample();
        lOut += ch.outL;
        rOut += ch.outR;
      }
      // Mix background voices (IT NNA)
      for (int bg = backgroundVoices.length - 1; bg >= 0; bg--) {
        final bgv = backgroundVoices[bg];
        if (!bgv.playing) {
          backgroundVoices.removeAt(bg);
          continue;
        }
        bgv.nextSample();
        lOut += bgv.outL;
        rOut += bgv.outR;
      }

      double finalL = lOut * 0.42 * masterVolume;
      double finalR = rOut * 0.42 * masterVolume;
      if (stereoWidth != 1.0) {
        final mid = (finalL + finalR) / 2.0;
        final sideL = finalL - mid;
        final sideR = finalR - mid;
        finalL = mid + sideL * stereoWidth;
        finalR = mid + sideR * stereoWidth;
      }
      if (amigaFilter) {
        finalL = _applyAmigaFilterL(finalL);
        finalR = _applyAmigaFilterR(finalR);
      }
      out[2 * i] = _tanh(finalL);
      out[2 * i + 1] = _tanh(finalR);
    }
  }
}
