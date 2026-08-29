import 'package:flutter/material.dart';

import 'engine/tile.dart';

/// Ricochet's own palette. The board is a deliberately dark, saturated arcade
/// scene rather than a themed surface, so these are literal values and not
/// pulled from `AppTheme` — the game reads the same in light and dark mode.
class RicochetColors {
  RicochetColors._();

  static const Color board = Color(0xFF10121C);

  /// The surround behind the board. Darker than [board] so the playfield reads
  /// as a distinct area rather than bleeding into the page.
  static const Color page = Color(0xFF06070C);

  /// The walls a ball bounces off. Without an explicit rim the board's edges
  /// are invisible against the surround, and the player cannot see where a
  /// shot will come back from.
  static const Color wall = Color(0xFF3E4A66);

  static const Color launcher = Color(0xFF38BDF8);
  static const Color ball = Color(0xFFF8FAFC);
  static const Color ballTrail = Color(0xFF7DD3FC);
  static const Color danger = Color(0xFFF87171);

  static const Color gift = Color(0xFF10B981);
  static const Color mult = Color(0xFFF59E0B);
  static const Color pierce = Color(0xFF8B5CF6);
  static const Color pierceLight = Color(0xFFA78BFA);
  static const Color blast = Color(0xFFEF4444);
  static const Color blastLight = Color(0xFFFB923C);
  static const Color ramp = Color(0xFF22D3EE);
  static const Color orb = Color(0xFF94A3B8);
  static const Color pickup = Color(0xFF34D399);
  static const Color bombBody = Color(0xFF334155);
  static const Color bombRim = Color(0xFF7C8BA1);
  static const Color fuse = Color(0xFFFDE047);
  static const Color bonus = Color(0xFFFBBF24);
  static const Color info = Color(0xFF38BDF8);

  /// Plain bricks are coloured by how tough they are: orange at 1 HP sweeping
  /// through the hue circle to violet at 50+, so a board's difficulty is
  /// readable at a glance without reading a single number.
  static Color byHp(int hp) {
    final t = ((hp - 1) / 49).clamp(0.0, 1.0);
    return HSLColor.fromAHSL(
      1,
      (30 + t * 255) % 360,
      0.72,
      (52 - t * 8) / 100,
    ).toColor();
  }

  static Color forTile(Brick brick) {
    switch (brick.type) {
      case TileType.gift:
        return gift;
      case TileType.mult:
        return mult;
      case TileType.pierce:
        return pierce;
      case TileType.blast:
        return blast;
      case TileType.rampA:
      case TileType.rampB:
        return ramp;
      case TileType.orb:
        return orb;
      case TileType.bomb:
      case TileType.normal:
        return byHp(brick.hp);
    }
  }
}
