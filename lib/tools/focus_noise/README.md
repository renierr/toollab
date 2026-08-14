# Focus Noise Tool

This tool is built to make adding sounds easy.

Current defaults are fully generated at runtime (including Forest/City). Each
one is pre-rendered once into a loop-ready WAV and looped natively, so no Dart
timer feeds playback.

Two things keep the loop wrap inaudible, both in `engine/noise_loop_builder.dart`:

- The seam is closed with an **equal-power** (sin/cos) crossfade against extra
  audio rendered past the loop end. Linear weights would lose ~3 dB mid-fade,
  because the two sides are uncorrelated noise.
- The fade length is per noise type — the more low-frequency energy a noise
  carries, the longer it needs (brown most, white/green least).

## Sound types

- `generated`: PCM noise produced at runtime (infinite, no asset file).
- `asset`: bundled loop file from `assets/audio/`.

Both types are declared in one place: `lib/tools/focus_noise/focus_noise_sound.dart`.

## Add a new generated sound

1. Add item to `FocusNoiseCatalog.sounds` in `lib/tools/focus_noise/focus_noise_sound.dart`:

```dart
FocusNoiseSound(
  id: 'my-noise',
  name: 'My Noise',
  icon: Icons.graphic_eq,
  kind: FocusNoiseSoundKind.generated,
),
```

2. Map this `id` to a generator type in `lib/tools/focus_noise/engine/focus_noise_player.dart`:

```dart
final GeneratedNoiseType type = switch (sound.id) {
  'white' => GeneratedNoiseType.white,
  'pink' => GeneratedNoiseType.pink,
  'my-noise' => GeneratedNoiseType.white,
  _ => GeneratedNoiseType.brown,
};
```

3. If needed, add a new enum value + algorithm in `lib/tools/focus_noise/engine/noise_pcm_generator.dart`.

## Add a new asset sound

1. Put loop file into `assets/audio/` (prefer 48kHz, stereo, seamless loop).
2. Ensure `pubspec.yaml` includes `assets/audio/` (already configured).
3. Add catalog item in `lib/tools/focus_noise/focus_noise_sound.dart`:

```dart
FocusNoiseSound(
  id: 'rain',
  name: 'Rain',
  icon: Icons.water_drop_outlined,
  kind: FocusNoiseSoundKind.asset,
  assetPath: 'assets/audio/rain_loop_60s.wav',
),
```

No player changes are needed for new asset sounds.

## Rules for good loops

- Keep peak below `-1 dBFS` to avoid clipping.
- Use seamless head/tail matching or crossfaded loop render.
- Prefer long loops (30s-120s) to reduce repetition.
- Use license-free content you can redistribute in app bundles.

## Runtime behavior

- During playback, tool acquires partial wake lock + foreground runtime lease.
- On stop (manual or timer end), tool releases both leases.

Implementation: `lib/tools/focus_noise/engine/focus_noise_player.dart`.
