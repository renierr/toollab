import 'package:flutter/material.dart';

class LumaWellColors {
  LumaWellColors._();

  static const Color page = Color(0xFF07131B);
  static const Color well = Color(0xFF0D2632);
  static const Color wellEdge = Color(0xFF1C4C5F);
  static const Color slot = Color(0xFF123542);
  static const Color score = Color(0xFFF7C65B);
  static const Color best = Color(0xFF7BE1C6);

  static const Color fieldBackground = Color(0xFF080A11);
  static const Color starDust = Colors.white;
  static const Color terrain = Color(0xFF1C2029);
  static const Color planetCore = Color(0xFF3A414B);
  static const Color planetShadow = Color(0xFF171A21);

  static const Color orbKindLow = Color(0xFFFFAE3D);
  static const Color orbKindMid = Color(0xFFFF744B);
  static const Color orbKindHigh = Color(0xFFE04E8A);
  static const Color orbKindHighest = Color(0xFFB464E8);
  static const Color orbBorder = Colors.white;
  static const Color orbLabel = Colors.white;

  static const Color powerCharge = Color(0xFFFFD26A);
  static const Color powerExpand = Color(0xFF52DDE6);
  static const Color powerFocus = Color(0xFFB464E8);
  static const Color mergeGlow = Color(0xFFFFA52E);
  static const Color volatileOrb = Color(0xFF5A1620);
  static const Color volatileLabel = Color(0xFFFF8A9B);
  static const Color comboBadge = Color(0xFFFFD26A);

  static const Color ringNormal = Colors.white;
  static const Color ringBlocked = Colors.redAccent;

  static Color orbKindColor(int kind) => switch (kind) {
    0 => orbKindLow,
    1 => orbKindMid,
    2 => orbKindHigh,
    _ => orbKindHighest,
  };

  static const List<Color> _planetCores = [
    Color(0xFF4A5A6A),
    Color(0xFF2E8C83),
    Color(0xFF7A5FD0),
    Color(0xFFC04E8A),
    Color(0xFFD97A3D),
    Color(0xFFD9B23D),
  ];

  static const List<Color> _planetShadows = [
    Color(0xFF171A21),
    Color(0xFF0E2A28),
    Color(0xFF241B45),
    Color(0xFF3A1430),
    Color(0xFF3A1E10),
    Color(0xFF3A2E0E),
  ];

  static Color planetCoreForStage(int stage) =>
      _planetCores[(stage - 1).clamp(0, _planetCores.length - 1)];

  static Color planetShadowForStage(int stage) =>
      _planetShadows[(stage - 1).clamp(0, _planetShadows.length - 1)];

  static const List<Color> _levels = [    Color(0xFF5CC8FF),
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
