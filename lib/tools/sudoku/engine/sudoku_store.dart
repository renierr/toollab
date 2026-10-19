import 'dart:convert';

import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/services/database_service.dart';

import '../config.dart';
import 'sudoku_generator.dart';
import 'sudoku_stats.dart';

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

  Future<void> saveBestTime(SudokuDifficulty difficulty, int seconds) =>
      _write('$_keyBestPrefix${difficulty.name}', seconds.toString());

  Future<SudokuStats> loadStats() async {
    final stats = _decodeStats(await _read(_keyStats));
    for (final d in SudokuDifficulty.values) {
      stats[d].bestTime = int.tryParse(
        await _read('$_keyBestPrefix${d.name}') ?? '',
      );
    }
    return stats;
  }

  SudokuStats _decodeStats(String? raw) {
    if (raw == null || raw.isEmpty) return SudokuStats();
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic>
          ? SudokuStats.fromJson(decoded)
          : SudokuStats();
    } catch (e) {
      errorLog('[Sudoku] Discarding unreadable stats: $e');
      return SudokuStats();
    }
  }

  Future<void> saveStats(SudokuStats stats) =>
      _write(_keyStats, jsonEncode(stats.toJson()));

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
