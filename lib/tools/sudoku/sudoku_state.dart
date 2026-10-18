import 'package:flutter/foundation.dart';
import 'package:tool_lab/services/database_service.dart';

import 'config.dart';

class SudokuState extends ChangeNotifier {
  static const String _soundKey = 'sound_enabled';
  static const String _hapticsKey = 'haptics_enabled';
  static const String _autoCheckKey = 'auto_check';
  static const String _maxMistakesKey = 'max_mistakes';
  static const String _highlightConflictsKey = 'highlight_conflicts';
  static const String _highlightSameKey = 'highlight_same';
  static const String _showTimerKey = 'show_timer';
  static const String _hintsPerGameKey = 'hints_per_game';

  bool _soundEnabled = true;
  bool _hapticsEnabled = true;
  bool _autoCheck = true;
  int _maxMistakes = 0; // 0 = unlimited (casual)
  bool _highlightConflicts = true;
  bool _highlightSameNumber = true;
  bool _showTimer = false;
  int _hintsPerGame = 9999; // unlimited hints

  bool get soundEnabled => _soundEnabled;
  bool get hapticsEnabled => _hapticsEnabled;
  bool get autoCheck => _autoCheck;
  int get maxMistakes => _maxMistakes;
  bool get highlightConflicts => _highlightConflicts;
  bool get highlightSameNumber => _highlightSameNumber;
  bool get showTimer => _showTimer;
  int get hintsPerGame => _hintsPerGame;

  Future<void> restore() async {
    final db = DatabaseService.instance;
    final id = SudokuTool.config.id;
    _soundEnabled = (await db.getSetting(id, _soundKey)) != 'false';
    _hapticsEnabled = (await db.getSetting(id, _hapticsKey)) != 'false';
    _autoCheck = (await db.getSetting(id, _autoCheckKey)) != 'false';
    _maxMistakes = 0; // unlimited
    _highlightConflicts =
        (await db.getSetting(id, _highlightConflictsKey)) != 'false';
    _highlightSameNumber =
        (await db.getSetting(id, _highlightSameKey)) != 'false';
    _showTimer = (await db.getSetting(id, _showTimerKey)) != 'false';
    _hintsPerGame = 9999; // unlimited hints
    notifyListeners();
  }

  Future<void> _set(String key, String value) async {
    await DatabaseService.instance.setSetting(SudokuTool.config.id, key, value);
  }

  Future<void> setSoundEnabled(bool v) async {
    if (_soundEnabled == v) return;
    _soundEnabled = v;
    notifyListeners();
    await _set(_soundKey, v.toString());
  }

  Future<void> setHapticsEnabled(bool v) async {
    if (_hapticsEnabled == v) return;
    _hapticsEnabled = v;
    notifyListeners();
    await _set(_hapticsKey, v.toString());
  }

  Future<void> setAutoCheck(bool v) async {
    if (_autoCheck == v) return;
    _autoCheck = v;
    notifyListeners();
    await _set(_autoCheckKey, v.toString());
  }

  Future<void> setMaxMistakes(int v) async {
    if (_maxMistakes == v) return;
    _maxMistakes = v;
    notifyListeners();
    await _set(_maxMistakesKey, v.toString());
  }

  Future<void> setHighlightConflicts(bool v) async {
    if (_highlightConflicts == v) return;
    _highlightConflicts = v;
    notifyListeners();
    await _set(_highlightConflictsKey, v.toString());
  }

  Future<void> setHighlightSameNumber(bool v) async {
    if (_highlightSameNumber == v) return;
    _highlightSameNumber = v;
    notifyListeners();
    await _set(_highlightSameKey, v.toString());
  }

  Future<void> setShowTimer(bool v) async {
    if (_showTimer == v) return;
    _showTimer = v;
    notifyListeners();
    await _set(_showTimerKey, v.toString());
  }

  Future<void> setHintsPerGame(int v) async {
    if (_hintsPerGame == v) return;
    _hintsPerGame = v;
    notifyListeners();
    await _set(_hintsPerGameKey, v.toString());
  }
}
