import 'package:flutter/foundation.dart';
import 'package:tool_lab/services/database_service.dart';

import 'config.dart';

class SudokuState extends ChangeNotifier {
  static const String _hapticsKey = 'haptics_enabled';
  static const String _autoCheckKey = 'auto_check';
  static const String _highlightConflictsKey = 'highlight_conflicts';
  static const String _highlightSameKey = 'highlight_same';
  static const String _showTimerKey = 'show_timer';

  bool _hapticsEnabled = true;
  bool _autoCheck = true;
  bool _highlightConflicts = true;
  bool _highlightSameNumber = true;
  bool _showTimer = true;

  bool get hapticsEnabled => _hapticsEnabled;
  bool get autoCheck => _autoCheck;
  bool get highlightConflicts => _highlightConflicts;
  bool get highlightSameNumber => _highlightSameNumber;
  bool get showTimer => _showTimer;

  Future<void> restore() async {
    final db = DatabaseService.instance;
    final id = SudokuTool.config.id;
    Future<bool> read(String key) async =>
        (await db.getSetting(id, key)) != 'false';

    _hapticsEnabled = await read(_hapticsKey);
    _autoCheck = await read(_autoCheckKey);
    _highlightConflicts = await read(_highlightConflictsKey);
    _highlightSameNumber = await read(_highlightSameKey);
    _showTimer = await read(_showTimerKey);
    notifyListeners();
  }

  Future<void> _set(String key, bool value) async {
    notifyListeners();
    await DatabaseService.instance.setSetting(
      SudokuTool.config.id,
      key,
      value.toString(),
    );
  }

  Future<void> setHapticsEnabled(bool v) async {
    if (_hapticsEnabled == v) return;
    _hapticsEnabled = v;
    await _set(_hapticsKey, v);
  }

  Future<void> setAutoCheck(bool v) async {
    if (_autoCheck == v) return;
    _autoCheck = v;
    await _set(_autoCheckKey, v);
  }

  Future<void> setHighlightConflicts(bool v) async {
    if (_highlightConflicts == v) return;
    _highlightConflicts = v;
    await _set(_highlightConflictsKey, v);
  }

  Future<void> setHighlightSameNumber(bool v) async {
    if (_highlightSameNumber == v) return;
    _highlightSameNumber = v;
    await _set(_highlightSameKey, v);
  }

  Future<void> setShowTimer(bool v) async {
    if (_showTimer == v) return;
    _showTimer = v;
    await _set(_showTimerKey, v);
  }
}
