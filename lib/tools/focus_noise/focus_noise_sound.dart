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
      id: 'forest',
      name: 'Forest',
      icon: Icons.park_outlined,
      kind: FocusNoiseSoundKind.generated,
    ),
    FocusNoiseSound(
      id: 'city',
      name: 'City',
      icon: Icons.location_city_outlined,
      kind: FocusNoiseSoundKind.generated,
    ),
    FocusNoiseSound(
      id: 'rain',
      name: 'Rain',
      icon: Icons.water_drop_outlined,
      kind: FocusNoiseSoundKind.generated,
    ),
    FocusNoiseSound(
      id: 'waves',
      name: 'Waves',
      icon: Icons.waves_outlined,
      kind: FocusNoiseSoundKind.generated,
    ),
  ];

  static FocusNoiseSound byId(String id) {
    return sounds.firstWhere(
      (sound) => sound.id == id,
      orElse: () => sounds[0],
    );
  }
}
