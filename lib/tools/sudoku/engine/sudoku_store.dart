import 'dart:convert';

import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/services/database_service.dart';

import '../config.dart';

class SudokuStore {
  static const String _keySave = 'save';
  static const String _keyStats = 'stats';
  static const String _keyBestPrefix = 'best_';

  const SudokuStore();

  Future<Map<String, dynamic>?> loadSave() async {
    final raw = await _read(_keySave);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (e) {
      errorLog('[Sudoku] Discarding unreadable save: $e');
      return null;
    }
  }

  Future<void> saveSave(Map<String, dynamic> data) =>
      _write(_keySave, jsonEncode(data));

  Future<void> clearSave() => _delete(_keySave);

  Future<int?> loadBestTime(String difficulty) async {
    final raw = await _read('$_keyBestPrefix$difficulty');
    return int.tryParse(raw ?? '');
  }

  Future<void> saveBestTime(String difficulty, int seconds) =>
      _write('$_keyBestPrefix$difficulty', seconds.toString());

  Future<Map<String, dynamic>> loadStats() async {
    final raw = await _read(_keyStats);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : {};
    } catch (e) {
      errorLog('[Sudoku] Discarding unreadable stats: $e');
      return {};
    }
  }

  Future<void> saveStats(Map<String, dynamic> data) =>
      _write(_keyStats, jsonEncode(data));

  Future<String?> _read(String key) async {
    try {
      return await DatabaseService.instance.getSetting(
        SudokuTool.config.id,
        key,
      );
    } catch (e) {
      errorLog('[Sudoku] Could not read "$key": $e');
      return null;
    }
  }

  Future<void> _write(String key, String value) async {
    try {
      await DatabaseService.instance.setSetting(
        SudokuTool.config.id,
        key,
        value,
      );
    } catch (e) {
      errorLog('[Sudoku] Could not save "$key": $e');
    }
  }

  Future<void> _delete(String key) async {
    try {
      await DatabaseService.instance.deleteSetting(SudokuTool.config.id, key);
    } catch (e) {
      errorLog('[Sudoku] Could not delete "$key": $e');
    }
  }
}
