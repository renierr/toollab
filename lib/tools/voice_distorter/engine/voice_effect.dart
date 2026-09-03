import 'dart:math' as math;

/// The seven knobs every voice effect (built-in or custom) is made of.
/// Kept immutable — presets and slider edits both just produce a new instance.
class VoiceEffectParams {
  final double pitchSemitones; // -24..24
  final double formantSemitones; // -12..12, the size of the voice's "body"
  final double robotAmount; // 0..1
  final double echoAmount; // 0..1
  final double reverbAmount; // 0..1
  final double lofiAmount; // 0..1
  final double distortionAmount; // 0..1

  const VoiceEffectParams({
    this.pitchSemitones = 0,
    this.formantSemitones = 0,
    this.robotAmount = 0,
    this.echoAmount = 0,
    this.reverbAmount = 0,
    this.lofiAmount = 0,
    this.distortionAmount = 0,
  });

  /// Playback rate that moves the formants. Resampling shifts pitch and
  /// formants together, so it also stretches the clip in time.
  double get playbackRate => math.pow(2, formantSemitones / 12).toDouble();

  /// What the pitch-shift filter has to undo of [playbackRate] to leave the
  /// perceived pitch at [pitchSemitones]. Clamped to the filter's own range.
  double get filterSemitones =>
      (pitchSemitones - formantSemitones).clamp(-36.0, 36.0);

  VoiceEffectParams copyWith({
    double? pitchSemitones,
    double? formantSemitones,
    double? robotAmount,
    double? echoAmount,
    double? reverbAmount,
    double? lofiAmount,
    double? distortionAmount,
  }) => VoiceEffectParams(
    pitchSemitones: pitchSemitones ?? this.pitchSemitones,
    formantSemitones: formantSemitones ?? this.formantSemitones,
    robotAmount: robotAmount ?? this.robotAmount,
    echoAmount: echoAmount ?? this.echoAmount,
    reverbAmount: reverbAmount ?? this.reverbAmount,
    lofiAmount: lofiAmount ?? this.lofiAmount,
    distortionAmount: distortionAmount ?? this.distortionAmount,
  );
}

/// A named, selectable effect: either one of the built-in [VoicePresets] or a
/// user-saved custom preset (`dbId` set, loaded from `VoicePresetsDbHelper`).
class VoicePreset {
  final int? dbId;
  final String id;
  final String name;
  final VoiceEffectParams params;

  const VoicePreset({
    this.dbId,
    required this.id,
    required this.name,
    required this.params,
  });

  bool get isCustom => dbId != null;
}

/// Fixed, hand-tuned built-in presets covering distinct voice characters.
/// Localized display names are resolved by id in the UI via `AppLocalizations`.
class VoicePresets {
  VoicePresets._();

  static const List<VoicePreset> all = [
    VoicePreset(
      id: 'chipmunk',
      name: 'Chipmunk',
      params: VoiceEffectParams(pitchSemitones: 9, formantSemitones: 5),
    ),
    VoicePreset(
      id: 'helium',
      name: 'Helium',
      params: VoiceEffectParams(pitchSemitones: 14, formantSemitones: 7),
    ),
    VoicePreset(
      id: 'deep_voice',
      name: 'Deep Voice',
      params: VoiceEffectParams(pitchSemitones: -7, formantSemitones: -3),
    ),
    VoicePreset(
      id: 'giant',
      name: 'Giant',
      params: VoiceEffectParams(
        pitchSemitones: -14,
        formantSemitones: -7,
        reverbAmount: 0.25,
      ),
    ),
    VoicePreset(
      id: 'robot',
      name: 'Robot',
      params: VoiceEffectParams(robotAmount: 0.85, pitchSemitones: -1),
    ),
    VoicePreset(
      id: 'cyborg',
      name: 'Cyborg',
      params: VoiceEffectParams(
        robotAmount: 0.5,
        pitchSemitones: -5,
        formantSemitones: -2,
        distortionAmount: 0.2,
      ),
    ),
    VoicePreset(
      id: 'alien',
      name: 'Alien',
      // High pitch out of a large body — impossible with plain resampling.
      params: VoiceEffectParams(
        pitchSemitones: 6,
        formantSemitones: -5,
        robotAmount: 0.35,
        reverbAmount: 0.2,
      ),
    ),
    VoicePreset(
      id: 'telephone',
      name: 'Telephone',
      params: VoiceEffectParams(lofiAmount: 0.75, pitchSemitones: 1),
    ),
    VoicePreset(
      id: 'radio',
      name: 'Radio',
      params: VoiceEffectParams(lofiAmount: 0.5, distortionAmount: 0.15),
    ),
    VoicePreset(
      id: 'ghost',
      name: 'Ghost',
      params: VoiceEffectParams(
        reverbAmount: 0.85,
        echoAmount: 0.4,
        pitchSemitones: -3,
        formantSemitones: 3,
      ),
    ),
    VoicePreset(
      id: 'monster',
      name: 'Monster',
      params: VoiceEffectParams(
        pitchSemitones: -16,
        formantSemitones: -6,
        distortionAmount: 0.55,
        reverbAmount: 0.3,
      ),
    ),
    VoicePreset(
      id: 'dark_lord',
      name: 'Dark Lord',
      params: VoiceEffectParams(
        pitchSemitones: -9,
        formantSemitones: -4,
        echoAmount: 0.3,
        robotAmount: 0.15,
      ),
    ),
  ];
}
