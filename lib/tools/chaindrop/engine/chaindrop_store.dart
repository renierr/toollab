import 'dart:convert';

import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/services/database_service.dart';

import '../config.dart';

/// Chain Drop's persistence: the board in progress and the all-time best score.
class ChainDropStore {
  static const String _keySave = 'save';
  static const String _keyBest = 'best';

  const ChainDropStore();

  Future<int> loadBest() async =>
      int.tryParse(await _read(_keyBest) ?? '') ?? 0;

  Future<void> saveBest(int best) => _write(_keyBest, best.toString());

  Future<Map<String, dynamic>?> loadSave() => _readJson(_keySave);

  Future<void> writeSave(Map<String, dynamic> data) =>
      _write(_keySave, jsonEncode(data));

  Future<void> clearSave() => _delete(_keySave);

  Future<Map<String, dynamic>?> _readJson(String key) async {
    final raw = await _read(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (error) {
      errorLog('[ChainDrop] Discarding unreadable "$key": $error');
      return null;
    }
  }

  Future<void> _write(String key, String value) async {
    try {
      await DatabaseService.instance.setSetting(
        ChainDropTool.config.id,
        key,
        value,
      );
    } catch (error) {
      errorLog('[ChainDrop] Could not save "$key": $error');
    }
  }

  Future<void> _delete(String key) async {
    try {
      await DatabaseService.instance.deleteSetting(
        ChainDropTool.config.id,
        key,
      );
    } catch (error) {
      errorLog('[ChainDrop] Could not clear "$key": $error');
    }
  }

  Future<String?> _read(String key) async {
    try {
      return await DatabaseService.instance.getSetting(
        ChainDropTool.config.id,
        key,
      );
    } catch (error) {
      errorLog('[ChainDrop] Could not read "$key": $error');
      return null;
    }
  }
}
