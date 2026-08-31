import 'dart:convert';

import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/services/database_service.dart';

import '../config.dart';

class LumaWellStore {
  static const String _saveKey = 'save';
  static const String _bestKey = 'best';

  const LumaWellStore();

  Future<int> loadBest() async =>
      int.tryParse(await _read(_bestKey) ?? '') ?? 0;
  Future<void> saveBest(int value) => _write(_bestKey, value.toString());
  Future<void> clearSave() => _delete(_saveKey);
  Future<void> writeSave(Map<String, dynamic> value) =>
      _write(_saveKey, jsonEncode(value));

  Future<Map<String, dynamic>?> loadSave() async {
    final raw = await _read(_saveKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (error) {
      errorLog('[LumaWell] Could not read saved game: $error');
      return null;
    }
  }

  Future<String?> _read(String key) async {
    try {
      return await DatabaseService.instance.getSetting(
        LumaWellTool.config.id,
        key,
      );
    } catch (error) {
      errorLog('[LumaWell] Could not read "$key": $error');
      return null;
    }
  }

  Future<void> _write(String key, String value) async {
    try {
      await DatabaseService.instance.setSetting(
        LumaWellTool.config.id,
        key,
        value,
      );
    } catch (error) {
      errorLog('[LumaWell] Could not save "$key": $error');
    }
  }

  Future<void> _delete(String key) async {
    try {
      await DatabaseService.instance.deleteSetting(LumaWellTool.config.id, key);
    } catch (error) {
      errorLog('[LumaWell] Could not clear "$key": $error');
    }
  }
}
