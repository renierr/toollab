import 'package:flutter/material.dart';

/// 2048's own palette.
///
/// The original's beige tiles were designed for a white page. This is a dark
/// ramp instead — cool at 2, warming through amber and red, ending violet past
/// the target — so the board reads the same in light and dark mode and a
/// glance at the colour tells you roughly how far along a run is.
class Twenty48Colors {
  Twenty48Colors._();

  static const Color page = Color(0xFF0B0D14);
  static const Color board = Color(0xFF171A26);
  static const Color emptyCell = Color(0xFF20242F);
  static const Color score = Color(0xFFFBBF24);
  static const Color best = Color(0xFF34D399);

  /// Indexed by the tile's exponent minus one: 2 is `[0]`, 4 is `[1]`, and so
  /// on. Values past the end all use the last colour — by then the number
  /// itself is the interesting part.
  static const List<Color> _ramp = [
    Color(0xFF2E3A59), // 2
    Color(0xFF31527A), // 4
    Color(0xFF2E7BA6), // 8
    Color(0xFF1F9FA6), // 16
    Color(0xFF2FB37A), // 32
    Color(0xFF6FBF3C), // 64
    Color(0xFFC9B02C), // 128
    Color(0xFFE0902B), // 256
    Color(0xFFE06A2B), // 512
    Color(0xFFDC4A3D), // 1024
    Color(0xFFD4356B), // 2048
    Color(0xFFA23BC4), // 4096
    Color(0xFF6C40D9), // 8192 and beyond
  ];

  static Color forValue(int value) {
    var exponent = 0;
    var remaining = value;
    while (remaining > 2) {
      remaining >>= 1;
      exponent++;
    }
    return _ramp[exponent.clamp(0, _ramp.length - 1)];
  }

  /// The target tile gets a halo. It is the one moment in a run worth marking
  /// on the board itself rather than in a toast.
  static bool glows(int value) => value >= 2048;
}
