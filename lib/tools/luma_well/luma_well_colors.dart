import 'package:flutter/material.dart';

class LumaWellColors {
  LumaWellColors._();

  static const Color page = Color(0xFF07131B);
  static const Color well = Color(0xFF0D2632);
  static const Color wellEdge = Color(0xFF1C4C5F);
  static const Color slot = Color(0xFF123542);
  static const Color score = Color(0xFFF7C65B);
  static const Color best = Color(0xFF7BE1C6);

  static const List<Color> _levels = [
    Color(0xFF5CC8FF),
    Color(0xFF789BFF),
    Color(0xFFA878EF),
    Color(0xFFE275BE),
    Color(0xFFF08B6A),
    Color(0xFFF2BF5B),
    Color(0xFF89D267),
  ];

  static Color forLevel(int level) =>
      _levels[level.clamp(0, _levels.length - 1)];
}
