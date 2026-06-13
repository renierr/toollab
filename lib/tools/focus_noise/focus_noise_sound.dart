import 'package:flutter/material.dart';

enum FocusNoiseSoundKind { generated, asset }

class FocusNoiseSound {
  final String id;
  final String name;
  final IconData icon;
  final FocusNoiseSoundKind kind;
  final String? assetPath;

  const FocusNoiseSound({
    required this.id,
    required this.name,
    required this.icon,
    required this.kind,
    this.assetPath,
  });

  bool get isAsset => kind == FocusNoiseSoundKind.asset;
}

class FocusNoiseCatalog {
  FocusNoiseCatalog._();

  /// Quick checklist for adding sounds:
  /// 1) Add a new [FocusNoiseSound] entry below.
  /// 2) For generated sounds: map `id` in focus_noise_player.dart.
  /// 3) For asset sounds: place loop file in assets/audio/ and set assetPath.
  /// 4) Keep ids stable once shipped (settings persistence uses sound id).

  static const List<FocusNoiseSound> sounds = [
    FocusNoiseSound(
      id: 'white',
      name: 'White',
      icon: Icons.graphic_eq,
      kind: FocusNoiseSoundKind.generated,
    ),
    FocusNoiseSound(
      id: 'pink',
      name: 'Pink',
      icon: Icons.multitrack_audio,
      kind: FocusNoiseSoundKind.generated,
    ),
    FocusNoiseSound(
      id: 'brown',
      name: 'Brown',
      icon: Icons.terrain,
      kind: FocusNoiseSoundKind.generated,
    ),
    FocusNoiseSound(
      id: 'train',
      name: 'Train',
      icon: Icons.train_outlined,
      kind: FocusNoiseSoundKind.generated,
    ),
    FocusNoiseSound(
      id: 'green',
      name: 'Green',
      icon: Icons.nature_outlined,
      kind: FocusNoiseSoundKind.generated,
    ),
    FocusNoiseSound(
      id: 'forest',
      name: 'Forest',
      icon: Icons.park_outlined,
      kind: FocusNoiseSoundKind.asset,
      assetPath: 'assets/audio/forest.ogg',
    ),
    FocusNoiseSound(
      id: 'city',
      name: 'City',
      icon: Icons.location_city_outlined,
      kind: FocusNoiseSoundKind.asset,
      assetPath: 'assets/audio/city.ogg',
    ),
    FocusNoiseSound(
      id: 'rain',
      name: 'Rain',
      icon: Icons.water_drop_outlined,
      kind: FocusNoiseSoundKind.asset,
      assetPath: 'assets/audio/rain.ogg',
    ),
    FocusNoiseSound(
      id: 'rain_heavy',
      name: 'Rain (Heavy)',
      icon: Icons.water_drop,
      kind: FocusNoiseSoundKind.asset,
      assetPath: 'assets/audio/rain_heavy.ogg',
    ),
    FocusNoiseSound(
      id: 'waves',
      name: 'Ocean',
      icon: Icons.waves_outlined,
      kind: FocusNoiseSoundKind.asset,
      assetPath: 'assets/audio/waves.ogg',
    ),
    FocusNoiseSound(
      id: 'stream',
      name: 'Stream',
      icon: Icons.landscape_outlined,
      kind: FocusNoiseSoundKind.asset,
      assetPath: 'assets/audio/stream.ogg',
    ),
    FocusNoiseSound(
      id: 'night',
      name: 'Night',
      icon: Icons.nightlight_outlined,
      kind: FocusNoiseSoundKind.asset,
      assetPath: 'assets/audio/night.ogg',
    ),
    FocusNoiseSound(
      id: 'campfire',
      name: 'Campfire',
      icon: Icons.local_fire_department_outlined,
      kind: FocusNoiseSoundKind.asset,
      assetPath: 'assets/audio/campfire.ogg',
    ),
    FocusNoiseSound(
      id: 'countryside',
      name: 'Countryside',
      icon: Icons.wb_sunny_outlined,
      kind: FocusNoiseSoundKind.asset,
      assetPath: 'assets/audio/countryside.ogg',
    ),
    FocusNoiseSound(
      id: 'alpine',
      name: 'Alpine',
      icon: Icons.terrain_outlined,
      kind: FocusNoiseSoundKind.asset,
      assetPath: 'assets/audio/alpine.ogg',
    ),
    FocusNoiseSound(
      id: 'wind',
      name: 'Wind',
      icon: Icons.air_outlined,
      kind: FocusNoiseSoundKind.asset,
      assetPath: 'assets/audio/wind.ogg',
    ),
    FocusNoiseSound(
      id: 'birds_night',
      name: 'Birds at Night',
      icon: Icons.nightlife_outlined,
      kind: FocusNoiseSoundKind.asset,
      assetPath: 'assets/audio/birds_night.ogg',
    ),
    FocusNoiseSound(
      id: 'thunder',
      name: 'Thunder',
      icon: Icons.thunderstorm_outlined,
      kind: FocusNoiseSoundKind.asset,
      assetPath: 'assets/audio/rain_thunder.ogg',
    ),
  ];

  static FocusNoiseSound byId(String id) {
    return sounds.firstWhere(
      (sound) => sound.id == id,
      orElse: () => sounds[0],
    );
  }
}
