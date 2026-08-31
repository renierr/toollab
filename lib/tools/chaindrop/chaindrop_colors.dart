import 'package:flutter/material.dart';

/// Chain Drop's own palette: one hue per disc value 1-7, plus a neutral pair
/// for cracked discs that darkens as they take a second hit.
class ChainDropColors {
  ChainDropColors._();

  static const Color page = Color(0xFF0B0D14);
  static const Color board = Color(0xFF171A26);
  static const Color boardHighlight = Color(0xFF23283A);
  static const Color emptyCell = Color(0xFF20242F);
  static const Color score = Color(0xFFFBBF24);
  static const Color best = Color(0xFF34D399);

  static const Color crackedStage0 = Color(0xFF5B6472);
  static const Color crackedStage1 = Color(0xFF2E333C);

  static const List<Color> _ramp = [
    Color(0xFFE05A5A), // 1
    Color(0xFFE08A3D), // 2
    Color(0xFFDFC23D), // 3
    Color(0xFF6FBF5C), // 4
    Color(0xFF3FA8C7), // 5
    Color(0xFF5C74E0), // 6
    Color(0xFFA35CE0), // 7
  ];

  static Color forValue(int value) =>
      _ramp[(value - 1).clamp(0, _ramp.length - 1)];
}
