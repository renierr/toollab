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
      kind: FocusNoiseSoundKind.asset,
      assetPath: 'assets/audio/forest_loop_60s.wav',
    ),
    FocusNoiseSound(
      id: 'city',
      name: 'City',
      icon: Icons.location_city_outlined,
      kind: FocusNoiseSoundKind.asset,
      assetPath: 'assets/audio/city_loop_60s.wav',
    ),
  ];

  static FocusNoiseSound byId(String id) {
    return sounds.firstWhere(
      (sound) => sound.id == id,
      orElse: () => sounds[0],
    );
  }
}
