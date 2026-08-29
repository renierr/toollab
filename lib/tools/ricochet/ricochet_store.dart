import 'dart:convert';

import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/services/database_service.dart';

import 'config.dart';

class RicochetStore {
  static const String _keySave = 'save';
  static const String _keyCheckpoint = 'checkpoint';
  static const String _keyBest = 'best';

  const RicochetStore();

  Future<int> loadBest() async =>
      int.tryParse(await _read(_keyBest) ?? '') ?? 0;

  Future<void> saveBest(int best) => _write(_keyBest, best.toString());

  Future<Map<String, dynamic>?> loadSave() => _readJson(_keySave);

  Future<void> writeSave(Map<String, dynamic> data) =>
      _write(_keySave, jsonEncode(data));

  Future<void> clearSave() => _delete(_keySave);

  Future<Map<String, dynamic>?> loadCheckpoint() => _readJson(_keyCheckpoint);

  Future<void> writeCheckpoint(Map<String, dynamic> data) =>
      _write(_keyCheckpoint, jsonEncode(data));

  Future<Map<String, dynamic>?> _readJson(String key) async {
    final raw = await _read(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (error) {
      errorLog('[Ricochet] Discarding unreadable "$key": $error');
      return null;
    }
  }

  Future<void> _write(String key, String value) async {
    try {
      await DatabaseService.instance.setSetting(
        RicochetTool.config.id,
        key,
        value,
      );
    } catch (error) {
      errorLog('[Ricochet] Could not save "$key": $error');
    }
  }

  Future<void> _delete(String key) async {
    try {
      await DatabaseService.instance.deleteSetting(RicochetTool.config.id, key);
    } catch (error) {
      errorLog('[Ricochet] Could not clear "$key": $error');
    }
  }

  Future<String?> _read(String key) async {
    try {
      return await DatabaseService.instance.getSetting(
        RicochetTool.config.id,
        key,
      );
    } catch (error) {
      errorLog('[Ricochet] Could not read "$key": $error');
      return null;
    }
  }
}
