import 'package:flutter/material.dart';

class AppTheme {
  static const Color accentBlue = Color(0xFF4FC3F7);
  static const Color accentGreen = Color(0xFF66BB6A);
  static const Color accentAmber = Color(0xFFFFCA28);
  static const Color accentRed = Color(0xFFEF5350);
  static const Color accentPurple = Color(0xFFAB47BC);
  static const Color accentTeal = Color(0xFF26A69A);

  static const Color statusGreen = Color(0xFF66BB6A);
  static const Color statusAmber = Color(0xFFFFCA28);
  static const Color statusRed = Color(0xFFEF5350);
  static const Color statusBlue = Color(0xFF4FC3F7);
  static const Color statusOrange = Color(0xFFFF9800);
  static const Color favoriteStar = Color(0xFFFFCA28);

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorSchemeSeed: accentBlue,
    brightness: Brightness.light,
    appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
    cardTheme: CardThemeData(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    colorSchemeSeed: accentBlue,
    brightness: Brightness.dark,
    appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
    cardTheme: CardThemeData(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}
