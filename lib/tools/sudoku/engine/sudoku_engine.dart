import 'dart:async';

import 'package:flutter/foundation.dart';

import 'sudoku_generator.dart';
import 'sudoku_solver.dart';
import 'sudoku_store.dart';

class SudokuEngine extends ChangeNotifier {
  SudokuEngine({
    SudokuStore? store,
    this.autoCheck = true,
    this.maxMistakes = 0,
  }) : _store = store ?? const SudokuStore();

  final SudokuStore _store;

  bool autoCheck;
  int maxMistakes;
  int hintsPerGame = 9999;

  SudokuDifficulty _difficulty = SudokuDifficulty.medium;
  SudokuDifficulty get difficulty => _difficulty;

  List<int> _solution = List<int>.filled(81, 0);
  List<int> get solution => List<int>.unmodifiable(_solution);

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

  int _hintsRemaining = 9999;
  int get hintsRemaining => _hintsRemaining;

  int _elapsed = 0;
  int get elapsed => _elapsed;

  bool _paused = false;
  bool get paused => _paused;

  bool _completed = false;
  bool get completed => _completed;

  bool _gameOver = false;
  bool get gameOver => _gameOver;

  bool _notesMode = false;
  bool get notesMode => _notesMode;

  Timer? _timer;

  // Undo
  final List<_UndoEntry> _undo = [];
  bool get canUndo => _undo.isNotEmpty;

  // Stats cached
  Map<String, dynamic> _stats = {};

  Future<void> bootstrap() async {
    _stats = await _store.loadStats();
    final save = await _store.loadSave();
    if (save != null && save['completed'] != true && save['gameOver'] != true) {
      _restoreFromSave(save);
      _startTimer();
    } else {
      await _store.clearSave();
      await startNew(_difficulty);
    }
    notifyListeners();
  }

  Future<void> startNew(SudokuDifficulty difficulty) async {
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
    _hintsRemaining = hintsPerGame;
    _elapsed = 0;
    _paused = false;
    _completed = false;
    _gameOver = false;
    _notesMode = false;
    _undo.clear();
    // track played
    final diffKey = difficulty.name;
    final played = Map<String, dynamic>.from(_stats['played'] as Map? ?? {});
    played[diffKey] = (played[diffKey] as int? ?? 0) + 1;
    _stats['played'] = played;
    await _store.saveStats(_stats);
    _startTimer();
    await _persistSave();
    notifyListeners();
  }

  void selectCell(int index) {
    if (index < 0 || index > 80) return;
    if (_completed || _gameOver || _paused) return;
    _selected = index;
    notifyListeners();
  }

  Future<void> enterNumber(int value) async {
    if (_completed || _gameOver || _paused) return;
    final idx = _selected;
    if (idx < 0 || idx > 80) return;
    if (_given[idx]) return;
    if (value < 0 || value > 9) return;

    _pushUndo();

    if (_notesMode && value != 0) {
      if (_notes[idx].contains(value)) {
        _notes[idx].remove(value);
      } else {
        _notes[idx].add(value);
      }
    } else {
      _grid[idx] = value;
      _notes[idx].clear();
      if (value != 0 && autoCheck && value != _solution[idx]) {
        _mistakes++;
      }
      _checkCompletion();
    }
    await _persistSave();
    notifyListeners();
  }

  Future<void> erase() async {
    if (_completed || _gameOver || _paused) return;
    final idx = _selected;
    if (idx < 0 || idx > 80) return;
    if (_given[idx]) return;
    _pushUndo();
    _grid[idx] = 0;
    _notes[idx].clear();
    await _persistSave();
    notifyListeners();
  }

  void toggleNotesMode() {
    if (_completed || _gameOver) return;
    _notesMode = !_notesMode;
    notifyListeners();
  }

  Future<void> hint() async {
    if (_completed || _gameOver || _paused) return;
    // unlimited hints

    int target = -1;
    if (_selected >= 0 &&
        !_given[_selected] &&
        _grid[_selected] != _solution[_selected]) {
      target = _selected;
    } else {
      // find an empty or incorrect cell
      final candidates = <int>[];
      for (int i = 0; i < 81; i++) {
        if (_given[i]) continue;
        if (_grid[i] == 0 || _grid[i] != _solution[i]) candidates.add(i);
      }
      if (candidates.isEmpty) return;
      candidates.shuffle();
      target = candidates.first;
    }

    _pushUndo();
    _grid[target] = _solution[target];
    _notes[target].clear();
    // unlimited: do not decrement
    _selected = target;
    _checkCompletion();
    await _persistSave();
    notifyListeners();
  }

  Future<void> autoNotes() async {
    if (_completed || _gameOver || _paused) return;
    _pushUndo();
    for (int i = 0; i < 81; i++) {
      if (_given[i] || _grid[i] != 0) continue;
      _notes[i] = SudokuSolver.candidates(_grid, i);
    }
    await _persistSave();
    notifyListeners();
  }

  Future<void> clearNotes() async {
    if (_completed || _gameOver || _paused) return;
    _pushUndo();
    for (int i = 0; i < 81; i++) {
      _notes[i].clear();
    }
    await _persistSave();
    notifyListeners();
  }

  Future<void> undo() async {
    if (_undo.isEmpty) return;
    final entry = _undo.removeLast();
    for (int i = 0; i < 81; i++) {
      _grid[i] = entry.grid[i];
      _notes[i] = Set<int>.from(entry.notes[i]);
    }
    _mistakes = entry.mistakes;
    _hintsRemaining = entry.hints;
    _selected = entry.selected;
    // If was game over, revive? If mistakes reduced maybe still game over; keep simple: if mistakes < max, un-gameover?
    if (_gameOver && (maxMistakes == 0 || _mistakes < maxMistakes)) {
      _gameOver = false;
      if (!_completed) _startTimer();
    }
    await _persistSave();
    notifyListeners();
  }

  void pause() {
    if (_completed || _gameOver || _paused) return;
    _paused = true;
    _timer?.cancel();
    _persistSave();
    notifyListeners();
  }

  void resume() {
    if (_completed || _gameOver || !_paused) return;
    _paused = false;
    _startTimer();
    _persistSave();
    notifyListeners();
  }

  void setDifficulty(SudokuDifficulty d) {
    _difficulty = d;
    notifyListeners();
  }

  Future<void> abandon() async {
    _timer?.cancel();
    await _store.clearSave();
  }

  // Completion
  void _checkCompletion() {
    if (_completed) return;
    bool allFilled = true;
    for (int i = 0; i < 81; i++) {
      if (_grid[i] == 0) {
        allFilled = false;
        break;
      }
    }
    if (!allFilled) return;
    // all filled; check correctness
    bool correct = true;
    for (int i = 0; i < 81; i++) {
      if (_grid[i] != _solution[i]) {
        correct = false;
        break;
      }
    }
    if (!correct) return;
    _completed = true;
    _timer?.cancel();
    _onWin();
  }

  Future<void> _onWin() async {
    // update stats
    final diffKey = _difficulty.name;
    final played = Map<String, dynamic>.from(_stats['played'] as Map? ?? {});
    final won = Map<String, dynamic>.from(_stats['won'] as Map? ?? {});
    final streak = Map<String, dynamic>.from(_stats['streak'] as Map? ?? {});
    final bestStreak = Map<String, dynamic>.from(
      _stats['bestStreak'] as Map? ?? {},
    );

    played[diffKey] =
        (played[diffKey] as int? ?? 0) +
        1; // count win as played too? We'll increment played on start instead maybe. Keep played on win? Let's increment played on new game. Hmm.
    // We'll instead increment played in startNew. So here only won.
    won[diffKey] = (won[diffKey] as int? ?? 0) + 1;
    final cur = (streak[diffKey] as int? ?? 0) + 1;
    streak[diffKey] = cur;
    final bs = (bestStreak[diffKey] as int? ?? 0);
    if (cur > bs) bestStreak[diffKey] = cur;

    _stats['played'] = played;
    _stats['won'] = won;
    _stats['streak'] = streak;
    _stats['bestStreak'] = bestStreak;
    await _store.saveStats(_stats);

    // best time
    final best = await _store.loadBestTime(diffKey);
    if (best == null || _elapsed < best) {
      await _store.saveBestTime(diffKey, _elapsed);
    }
    await _persistSave();
  }

  // Track played count: increment on startNew
  // We'll adjust: in startNew, increment played stat. But _stats loaded in bootstrap. Need ensure loaded. startNew may be called before bootstrap? bootstrap calls startNew after loadStats, so _stats loaded. But direct startNew from UI after bootstrap okay. However if startNew called, _stats already loaded. Good. But increment played there.
  // Let's override: in startNew, after generating, increment played.
  // We'll add that in startNew via helper. But startNew currently doesn't. Let's add now by editing? We'll modify: add increment played at end of startNew. We'll patch via edit later.

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_paused || _completed || _gameOver) return;
      _elapsed++;
      notifyListeners();
    });
  }

  void _pushUndo() {
    _undo.add(
      _UndoEntry(
        grid: List<int>.from(_grid),
        notes: _notes.map((s) => Set<int>.from(s)).toList(),
        mistakes: _mistakes,
        hints: _hintsRemaining,
        selected: _selected,
      ),
    );
    if (_undo.length > 200) _undo.removeAt(0);
  }

  Future<void> _persistSave() async {
    final data = {
      'difficulty': _difficulty.name,
      'solution': _solution,
      'grid': _grid,
      'given': _given,
      'notes': _notes.map((s) => s.toList()).toList(),
      'mistakes': _mistakes,
      'maxMistakes': maxMistakes,
      'hintsRemaining': _hintsRemaining,
      'elapsed': _elapsed,
      'paused': _paused,
      'completed': _completed,
      'gameOver': _gameOver,
      'notesMode': _notesMode,
      'autoCheck': autoCheck,
    };
    await _store.saveSave(data);
  }

  void _restoreFromSave(Map<String, dynamic> save) {
    final diffName = save['difficulty'] as String? ?? 'medium';
    _difficulty = SudokuDifficulty.values.firstWhere(
      (d) => d.name == diffName,
      orElse: () => SudokuDifficulty.medium,
    );
    final sol = (save['solution'] as List?)
        ?.map((e) => (e as num).toInt())
        .toList();
    if (sol != null && sol.length == 81) _solution = sol;
    final g = (save['grid'] as List?)?.map((e) => (e as num).toInt()).toList();
    if (g != null && g.length == 81) {
      for (int i = 0; i < 81; i++) {
        _grid[i] = g[i];
      }
    }
    final gv = save['given'] as List?;
    if (gv != null && gv.length == 81) {
      for (int i = 0; i < 81; i++) {
        _given[i] = gv[i] == true;
      }
    } else {
      for (int i = 0; i < 81; i++) {
        _given[i] = false;
      }
    }
    final n = save['notes'] as List?;
    if (n != null && n.length == 81) {
      for (int i = 0; i < 81; i++) {
        final v = n[i];
        if (v is List) {
          _notes[i] = v.map((e) => (e as num).toInt()).toSet();
        } else {
          _notes[i] = <int>{};
        }
      }
    }
    _mistakes = (save['mistakes'] as num?)?.toInt() ?? 0;
    maxMistakes = (save['maxMistakes'] as num?)?.toInt() ?? maxMistakes;
    _hintsRemaining = 9999;
    _elapsed = (save['elapsed'] as num?)?.toInt() ?? 0;
    _paused = save['paused'] == true;
    _completed = save['completed'] == true;
    _gameOver = save['gameOver'] == true;
    _notesMode = save['notesMode'] == true;
    autoCheck = save['autoCheck'] != false;
  }

  Future<Map<String, dynamic>> loadStats() async {
    _stats = await _store.loadStats();
    return _stats;
  }

  Map<String, dynamic> get stats => _stats;

  Future<int?> bestTime(String diff) => _store.loadBestTime(diff);

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

class _UndoEntry {
  final List<int> grid;
  final List<Set<int>> notes;
  final int mistakes;
  final int hints;
  final int selected;
  _UndoEntry({
    required this.grid,
    required this.notes,
    required this.mistakes,
    required this.hints,
    required this.selected,
  });
}
