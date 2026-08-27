import 'package:flutter/material.dart';

class EmfColors {
  EmfColors._();

  static const neonPink = Color(0xFFFF0055);
  static const neonCyan = Color(0xFF00F2FE);
  static const neonEmerald = Color(0xFF00FF87);
  static const amberYellow = Color(0xFFFFD200);
  static const gradientPurple = Color(0xFF9D50BB);
  static const gradientBlue = Color(0xFF4FACFE);

  static const darkBg = Color(0xFF0F1019);
  static const darkBgWarm = Color(0xFF14120E);
  static const darkBgDeep = Color(0xFF07080D);

  /// Greyscale steps of the neon-on-dark chrome, pinned to explicit values so
  /// the palette cannot drift with the Material grey swatch.
  static const inkBright = Color(0xFFEEEEEE);
  static const inkChip = Color(0xFFE0E0E0);
  static const inkMuted = Color(0xFFBDBDBD);
  static const inkDim = Color(0xFF9E9E9E);
  static const inkDisabled = Color(0xFF757575);
  static const trackIdle = Color(0xFF424242);
}
