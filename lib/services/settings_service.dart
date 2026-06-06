import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:tool_lab/services/database_service.dart';

class SettingsService {
  static const String _toolId = '_app';
  static const String _keyThemeMode = 'theme_mode';
  static const String _keyCompactMode = 'compact_mode';
  static const String _keySortBy = 'sort_by';
  static const String _keySyncEnabled = 'sync_enabled';
  static const String _keySyncServerUrl = 'sync_server_url';
  static const String _keySyncUserId = 'sync_user_id';
  static const String _keySyncLastSynced = 'sync_last_synced';

  static Future<SettingsService> init() async {
    final allSettings = await DatabaseService.instance.getAllSettings(_toolId);
    return SettingsService._(allSettings);
  }

  final Map<String, String> _cache;

  SettingsService._(this._cache);

  ThemeMode getThemeMode() {
    final index = _cache[_keyThemeMode];
    if (index == null) return ThemeMode.system;
    return ThemeMode.values[int.parse(index)];
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final value = mode.index.toString();
    _cache[_keyThemeMode] = value;
    await DatabaseService.instance.setSetting(_toolId, _keyThemeMode, value);
  }

  bool getCompactMode() {
    final value = _cache[_keyCompactMode];
    return value == 'true';
  }

  Future<void> setCompactMode(bool value) async {
    final str = value.toString();
    _cache[_keyCompactMode] = str;
    await DatabaseService.instance.setSetting(_toolId, _keyCompactMode, str);
  }

  String getSortBy() {
    return _cache[_keySortBy] ?? 'recent';
  }

  Future<void> setSortBy(String value) async {
    _cache[_keySortBy] = value;
    await DatabaseService.instance.setSetting(_toolId, _keySortBy, value);
  }

  bool getSyncEnabled() {
    final value = _cache[_keySyncEnabled];
    return value == 'true';
  }

  Future<void> setSyncEnabled(bool value) async {
    final str = value.toString();
    _cache[_keySyncEnabled] = str;
    await DatabaseService.instance.setSetting(_toolId, _keySyncEnabled, str);
  }

  String getSyncServerUrl() {
    return _cache[_keySyncServerUrl] ?? '';
  }

  Future<void> setSyncServerUrl(String value) async {
    _cache[_keySyncServerUrl] = value;
    await DatabaseService.instance.setSetting(
      _toolId,
      _keySyncServerUrl,
      value,
    );
  }

  String getSyncUserId() {
    return _cache[_keySyncUserId] ?? '';
  }

  Future<void> setSyncUserId(String value) async {
    _cache[_keySyncUserId] = value;
    await DatabaseService.instance.setSetting(_toolId, _keySyncUserId, value);
  }

  int getSyncLastSynced() {
    final value = _cache[_keySyncLastSynced];
    if (value == null) return 0;
    return int.tryParse(value) ?? 0;
  }

  Future<void> setSyncLastSynced(int value) async {
    final str = value.toString();
    _cache[_keySyncLastSynced] = str;
    await DatabaseService.instance.setSetting(_toolId, _keySyncLastSynced, str);
  }

  /// Exports all app settings as a JSON string.
  String exportSettingsToJson() {
    return jsonEncode(Map<String, dynamic>.from(_cache));
  }
}
