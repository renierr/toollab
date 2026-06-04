import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _keyThemeMode = 'theme_mode';
  static const String _keyCompactMode = 'compact_mode';
  static const String _keySortBy = 'sort_by';

  static Future<SettingsService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return SettingsService._(prefs);
  }

  final SharedPreferences _prefs;

  SettingsService._(this._prefs);

  ThemeMode getThemeMode() {
    final index = _prefs.getInt(_keyThemeMode);
    if (index == null) return ThemeMode.system;
    return ThemeMode.values[index];
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _prefs.setInt(_keyThemeMode, mode.index);
  }

  bool getCompactMode() {
    return _prefs.getBool(_keyCompactMode) ?? true;
  }

  Future<void> setCompactMode(bool value) async {
    await _prefs.setBool(_keyCompactMode, value);
  }

  String getSortBy() {
    return _prefs.getString(_keySortBy) ?? 'recent';
  }

  Future<void> setSortBy(String value) async {
    await _prefs.setString(_keySortBy, value);
  }
}
