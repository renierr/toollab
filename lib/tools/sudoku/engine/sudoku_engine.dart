import 'dart:async';

import 'package:flutter/foundation.dart';

import 'sudoku_generator.dart';
import 'sudoku_solver.dart';
import 'sudoku_stats.dart';
import 'sudoku_store.dart';

class SudokuEngine extends ChangeNotifier {
  SudokuEngine({SudokuStore? store}) : _store = store ?? const SudokuStore();

  static const int _maxUndo = 200;

  final SudokuStore _store;

  /// Counts wrong entries as mistakes and lets the board flag them.
  bool autoCheck = true;

  SudokuDifficulty _difficulty = SudokuDifficulty.medium;
  SudokuDifficulty get difficulty => _difficulty;

  List<int> _solution = List<int>.filled(81, 0);

  final List<int> _grid = List<int>.filled(81, 0);
  List<int> get grid => List<int>.unmodifiable(_grid);

  final List<bool> _given = List<bool>.filled(81, false);
  List<bool> get given => List<bool>.unmodifiable(_given);

  final List<Set<int>> _notes = List<Set<int>>.generate(81, (_) => <int>{});
  List<Set<int>> get notes => List<Set<int>>.unmodifiable(_notes);

  int _selected = -1;
  int get selected => _selected;

  int _mistakes = 0;
  int get mistakes => _mistakes;

  int _hintsUsed = 0;
  int get hintsUsed => _hintsUsed;

  // Ticks separately so the timer chip rebuilds without the board.
  final ValueNotifier<int> _elapsed = ValueNotifier<int>(0);
  ValueListenable<int> get elapsedListenable => _elapsed;
  int get elapsed => _elapsed.value;

  bool _paused = false;
  bool get paused => _paused;

  bool _completed = false;
  bool get completed => _completed;

  /// A game has been dealt and not yet won; starting another one breaks the streak.
  bool _active = false;

  bool _notesMode = false;
  bool get notesMode => _notesMode;

  Timer? _timer;

  final List<_UndoEntry> _undo = [];
  bool get canUndo => _undo.isNotEmpty;

  SudokuStats _stats = SudokuStats();
  SudokuStats get stats => _stats;

  bool get _locked => _completed || _paused;

  /// How many of each digit (index 1–9) are still to be placed.
  List<int> get remaining {
    final counts = List<int>.filled(10, 9);
    counts[0] = 0;
    for (final v in _grid) {
      if (v != 0) counts[v]--;
    }
    return counts;
  }

  /// Cells clashing with a peer, plus wrong entries when [includeWrong].
  Set<int> conflicts({required bool includeWrong}) {
    final result = <int>{};
    for (int i = 0; i < 81; i++) {
      final v = _grid[i];
      if (v == 0) continue;
      if (!SudokuSolver.isValidPlacement(_grid, i, v) ||
          (includeWrong && v != _solution[i])) {
        result.add(i);
      }
    }
    return result;
  }

  Future<void> bootstrap() async {
    _stats = await _store.loadStats();
    final save = await _store.loadSave();
    if (save != null && save['completed'] != true) {
      _restoreFromSave(save);
      _active = true;
      _startTimer();
    } else {
      await _store.clearSave();
      await startNew(_difficulty);
    }
    notifyListeners();
  }

  Future<void> startNew(SudokuDifficulty difficulty) async {
    if (_active) _stats[_difficulty].streak = 0;
    _difficulty = difficulty;
    _timer?.cancel();
    final (puzzle, solution) = SudokuGenerator.generate(difficulty);
    _solution = solution;
    for (int i = 0; i < 81; i++) {
      _grid[i] = puzzle[i];
      _given[i] = puzzle[i] != 0;
      _notes[i] = <int>{};
    }
    _selected = -1;
    _mistakes = 0;
    _hintsUsed = 0;
    _elapsed.value = 0;
    _paused = false;
    _completed = false;
    _active = true;
    _notesMode = false;
    _undo.clear();
    _stats[difficulty].played++;
    await _store.saveStats(_stats);
    _startTimer();
    await _persistSave();
    notifyListeners();
  }

  void selectCell(int index) {
    if (index < 0 || index > 80 || _locked) return;
    _selected = index;
    notifyListeners();
  }

  Future<void> enterNumber(int value) async {
    final idx = _selected;
    if (_locked || idx < 0 || _given[idx] || value < 0 || value > 9) return;

    _pushUndo();
    if (_notesMode && value != 0) {
      if (!_notes[idx].remove(value)) _notes[idx].add(value);
    } else {
      _grid[idx] = value;
      _notes[idx].clear();
      if (value != 0 && autoCheck && value != _solution[idx]) _mistakes++;
      await _checkCompletion();
    }
    await _persistSave();
    notifyListeners();
  }

  Future<void> erase() async {
    final idx = _selected;
    if (_locked || idx < 0 || _given[idx]) return;
    _pushUndo();
    _grid[idx] = 0;
    _notes[idx].clear();
    await _persistSave();
    notifyListeners();
  }

  void toggleNotesMode() {
    if (_completed) return;
    _notesMode = !_notesMode;
    notifyListeners();
  }

  Future<void> hint() async {
    if (_locked) return;

    int target;
    if (_selected >= 0 &&
        !_given[_selected] &&
        _grid[_selected] != _solution[_selected]) {
      target = _selected;
    } else {
      final candidates = [
        for (int i = 0; i < 81; i++)
          if (!_given[i] && _grid[i] != _solution[i]) i,
      ];
      if (candidates.isEmpty) return;
      target = (candidates..shuffle()).first;
    }

    _pushUndo();
    _grid[target] = _solution[target];
    _notes[target].clear();
    _hintsUsed++;
    _selected = target;
    await _checkCompletion();
    await _persistSave();
    notifyListeners();
  }

  Future<void> autoNotes() async {
    if (_locked) return;
    _pushUndo();
    for (int i = 0; i < 81; i++) {
      if (_grid[i] != 0) continue;
      _notes[i] = SudokuSolver.candidates(_grid, i);
    }
    await _persistSave();
    notifyListeners();
  }

  Future<void> clearNotes() async {
    if (_locked) return;
    _pushUndo();
    for (final n in _notes) {
      n.clear();
    }
    await _persistSave();
    notifyListeners();
  }

  Future<void> undo() async {
    if (_locked || _undo.isEmpty) return;
    final entry = _undo.removeLast();
    for (int i = 0; i < 81; i++) {
      _grid[i] = entry.grid[i];
      _notes[i] = Set<int>.from(entry.notes[i]);
    }
    _mistakes = entry.mistakes;
    _selected = entry.selected;
    await _persistSave();
    notifyListeners();
  }

  void pause() {
    if (_locked) return;
    _paused = true;
    _timer?.cancel();
    unawaited(_persistSave());
    notifyListeners();
  }

  void resume() {
    if (_completed || !_paused) return;
    _paused = false;
    _startTimer();
    unawaited(_persistSave());
    notifyListeners();
  }

  Future<void> _checkCompletion() async {
    for (int i = 0; i < 81; i++) {
      if (_grid[i] != _solution[i]) return;
    }
    _completed = true;
    _active = false;
    _timer?.cancel();

    final s = _stats[_difficulty];
    s.won++;
    s.streak++;
    if (s.streak > s.bestStreak) s.bestStreak = s.streak;
    await _store.saveStats(_stats);
    if (s.bestTime == null || elapsed < s.bestTime!) {
      s.bestTime = elapsed;
      await _store.saveBestTime(_difficulty, elapsed);
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_locked) _elapsed.value++;
    });
  }

  void _pushUndo() {
    _undo.add(
      _UndoEntry(
        grid: List<int>.from(_grid),
        notes: _notes.map((s) => Set<int>.from(s)).toList(),
        mistakes: _mistakes,
        selected: _selected,
      ),
    );
    if (_undo.length > _maxUndo) _undo.removeAt(0);
  }

  Future<void> _persistSave() => _store.saveSave({
    'difficulty': _difficulty.name,
    'solution': _solution,
    'grid': _grid,
    'given': _given,
    'notes': _notes.map((s) => s.toList()).toList(),
    'mistakes': _mistakes,
    'hintsUsed': _hintsUsed,
    'elapsed': elapsed,
    'paused': _paused,
    'completed': _completed,
    'notesMode': _notesMode,
  });

  void _restoreFromSave(Map<String, dynamic> save) {
    List<int>? ints(Object? raw) =>
        (raw as List?)?.map((e) => (e as num).toInt()).toList();

    _difficulty = SudokuDifficulty.values.firstWhere(
      (d) => d.name == save['difficulty'],
      orElse: () => SudokuDifficulty.medium,
    );
    final sol = ints(save['solution']);
    if (sol != null && sol.length == 81) _solution = sol;
    final g = ints(save['grid']);
    final gv = save['given'] as List?;
    final n = save['notes'] as List?;
    for (int i = 0; i < 81; i++) {
      if (g != null && g.length == 81) _grid[i] = g[i];
      _given[i] = gv != null && gv.length == 81 && gv[i] == true;
      if (n != null && n.length == 81) _notes[i] = ints(n[i])?.toSet() ?? {};
    }
    _mistakes = (save['mistakes'] as num?)?.toInt() ?? 0;
    _hintsUsed = (save['hintsUsed'] as num?)?.toInt() ?? 0;
    _elapsed.value = (save['elapsed'] as num?)?.toInt() ?? 0;
    _paused = save['paused'] == true;
    _completed = false;
    _notesMode = save['notesMode'] == true;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _elapsed.dispose();
    super.dispose();
  }
}

class _UndoEntry {
  final List<int> grid;
  final List<Set<int>> notes;
  final int mistakes;
  final int selected;
  _UndoEntry({
    required this.grid,
    required this.notes,
    required this.mistakes,
    required this.selected,
  });
}
