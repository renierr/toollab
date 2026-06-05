import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _keyThemeMode = 'theme_mode';
  static const String _keyCompactMode = 'compact_mode';
  static const String _keySortBy = 'sort_by';
  static const String _keySyncEnabled = 'sync_enabled';
  static const String _keySyncServerUrl = 'sync_server_url';
  static const String _keySyncUserId = 'sync_user_id';
  static const String _keySyncLastSynced = 'sync_last_synced';

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

  bool getSyncEnabled() {
    return _prefs.getBool(_keySyncEnabled) ?? false;
  }

  Future<void> setSyncEnabled(bool value) async {
    await _prefs.setBool(_keySyncEnabled, value);
  }

  String getSyncServerUrl() {
    return _prefs.getString(_keySyncServerUrl) ?? '';
  }

  Future<void> setSyncServerUrl(String value) async {
    await _prefs.setString(_keySyncServerUrl, value);
  }

  String getSyncUserId() {
    return _prefs.getString(_keySyncUserId) ?? '';
  }

  Future<void> setSyncUserId(String value) async {
    await _prefs.setString(_keySyncUserId, value);
  }

  int getSyncLastSynced() {
    return _prefs.getInt(_keySyncLastSynced) ?? 0;
  }

  Future<void> setSyncLastSynced(int value) async {
    await _prefs.setInt(_keySyncLastSynced, value);
  }
}
