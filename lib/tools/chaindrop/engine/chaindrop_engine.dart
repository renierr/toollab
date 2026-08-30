import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'chaindrop_store.dart';

/// The board's fixed logical size and pacing constants.
class ChainDropGrid {
  ChainDropGrid._();

  static const int columns = 7;
  static const int rows = 7;
  static const int cells = columns * rows;

  /// Successful drops between garbage-row insertions.
  static const int dropsPerGarbageRow = 6;
}

/// Sound/haptic event keys the engine fires mid-resolution. Kept as plain
/// strings with no audio dependency, so the engine never imports SoLoud.
class ChainDropSfxKeys {
  ChainDropSfxKeys._();

  static const String drop = 'drop';
  static const String pop = 'pop';
  static const String crackHit = 'crack_hit';
  static const String crackBreak = 'crack_break';
  static const String garbageRow = 'garbage_row';
  static const String gameOver = 'game_over';
}

/// One disc on the board.
///
/// [value] null means the disc is cracked (no number, [crackStage] 0 or 1)
/// rather than numbered. Row 0 is the bottom of the board.
class ChainDropDisc {
  final int id;
  int row;
  int col;
  int? value;
  int crackStage;

  /// Just placed — the view scales it in rather than sliding it.
  bool spawned;

  /// Marked to be removed at the end of this cascade round — the view flashes
  /// it before it disappears.
  bool popping;

  ChainDropDisc({
    required this.id,
    required this.row,
    required this.col,
    this.value,
    this.crackStage = 0,
    this.spawned = false,
    this.popping = false,
  });
}

/// The clone's simulation: dropping, run-length matching, cracked discs and
/// the escalating garbage rows.
///
/// A turn-based game, but a turn is not instantaneous — a drop can trigger a
/// multi-round cascade, and the view should see each round land rather than
/// only the final settled board. So a "move" here is `async`, `notifyListeners`
/// runs once per visible step, and short delays between steps give gravity and
/// pops room to read before the next round starts.
class ChainDropEngine extends ChangeNotifier {
  final ChainDropStore _store;
  final math.Random _random;

  static const Duration _dropDelay = Duration(milliseconds: 150);
  static const Duration _flashDelay = Duration(milliseconds: 190);
  static const Duration _gravityDelay = Duration(milliseconds: 170);

  final List<ChainDropDisc?> _grid = List<ChainDropDisc?>.filled(
    ChainDropGrid.cells,
    null,
  );
  final List<int> _queue = [];

  int _nextId = 1;
  int _score = 0;
  int _best = 0;
  int _level = 0;
  int _dropsSinceGarbage = 0;
  bool _resolving = false;
  bool _gameOver = false;

  /// Fired at each meaningful step of a drop's resolution. The page maps keys
  /// from [ChainDropSfxKeys] to sound/haptics; the engine never plays audio.
  void Function(String key)? onSfx;

  ChainDropEngine({ChainDropStore? store, math.Random? random})
    : _store = store ?? const ChainDropStore(),
      _random = random ?? math.Random();

  int get score => _score;
  int get best => _best;
  int get level => _level;
  bool get isResolving => _resolving;
  bool get isGameOver => _gameOver;
  List<int> get queue => List.unmodifiable(_queue);
  List<ChainDropDisc> get discs => _grid.whereType<ChainDropDisc>().toList();

  bool isColumnFull(int col) =>
      _grid[(ChainDropGrid.rows - 1) * ChainDropGrid.columns + col] != null;

  bool get _isFull => _grid.every((disc) => disc != null);

  // ------------------------------------------------------------------ lifecycle

  Future<void> start() async {
    _best = await _store.loadBest();
    final save = await _store.loadSave();
    if (save == null || !_hydrate(save)) {
      _deal();
    }
    notifyListeners();
  }

  void newGame() {
    _deal();
    unawaited(_store.clearSave());
    notifyListeners();
  }

  void _deal() {
    _grid.fillRange(0, ChainDropGrid.cells, null);
    _score = 0;
    _level = 0;
    _dropsSinceGarbage = 0;
    _resolving = false;
    _gameOver = false;
    _queue
      ..clear()
      ..addAll([_randomValue(), _randomValue(), _randomValue()]);
  }

  int _randomValue() => _random.nextInt(7) + 1;

  // ----------------------------------------------------------------------- play

  /// Drops the front of the queue into [column], then resolves every cascade
  /// round it triggers (and a garbage row, if this drop crosses the counter).
  /// Returns false without effect if the column is full, a drop is already
  /// resolving, or the game has ended.
  Future<bool> dropDisc(int column) async {
    if (_gameOver || _resolving || isColumnFull(column)) return false;

    _resolving = true;
    _clearTransientFlags();
    final value = _queue.removeAt(0);
    _queue.add(_randomValue());
    final row = _columnHeight(column);
    _grid[row * ChainDropGrid.columns + column] = ChainDropDisc(
      id: _nextId++,
      row: row,
      col: column,
      value: value,
      spawned: true,
    );
    _dropsSinceGarbage++;
    onSfx?.call(ChainDropSfxKeys.drop);
    notifyListeners();
    await Future.delayed(_dropDelay);

    await _resolveCascade();

    if (!_gameOver && _dropsSinceGarbage >= ChainDropGrid.dropsPerGarbageRow) {
      _dropsSinceGarbage = 0;
      _clearTransientFlags();
      final overflowed = _insertGarbageRow();
      onSfx?.call(ChainDropSfxKeys.garbageRow);
      notifyListeners();
      if (overflowed) {
        _endGame();
      } else {
        await Future.delayed(_dropDelay);
        await _resolveCascade();
      }
    }

    if (!_gameOver && _isFull) {
      _endGame();
    }

    _resolving = false;
    unawaited(_persist());
    notifyListeners();
    return true;
  }

  void _clearTransientFlags() {
    for (final disc in _grid.whereType<ChainDropDisc>()) {
      disc.spawned = false;
      disc.popping = false;
    }
  }

  int _columnHeight(int col) {
    var height = 0;
    for (var row = 0; row < ChainDropGrid.rows; row++) {
      if (_grid[row * ChainDropGrid.columns + col] == null) break;
      height++;
    }
    return height;
  }

  /// Repeats match → cracked-disc reaction → removal → gravity until a round
  /// pops nothing, which is what makes a single drop able to chain.
  Future<void> _resolveCascade() async {
    var round = 1;
    while (true) {
      _clearTransientFlags();
      final popped = _computeNumberedPops();
      if (popped.isEmpty) break;

      final crackedHit = <int>{};
      final crackedRemoved = <int>{};
      for (final index in popped) {
        for (final neighbor in _neighbors(index)) {
          final disc = _grid[neighbor];
          if (disc == null || disc.value != null) continue;
          if (crackedHit.contains(neighbor) ||
              crackedRemoved.contains(neighbor)) {
            continue;
          }
          if (disc.crackStage == 0) {
            crackedHit.add(neighbor);
          } else {
            crackedRemoved.add(neighbor);
          }
        }
      }

      for (final index in popped) {
        _grid[index]!.popping = true;
      }
      for (final index in crackedRemoved) {
        _grid[index]!.popping = true;
      }
      for (final index in crackedHit) {
        _grid[index]!.crackStage = 1;
      }

      var points = 0;
      for (final index in popped) {
        points += _grid[index]!.value! * 10;
      }
      points += crackedRemoved.length * 20;
      final totalCount = popped.length + crackedRemoved.length;
      if (totalCount > 1) points += (totalCount - 1) * 5;
      _score += points * round;
      if (_score > _best) {
        _best = _score;
        unawaited(_store.saveBest(_best));
      }

      onSfx?.call(
        crackedRemoved.isNotEmpty
            ? ChainDropSfxKeys.crackBreak
            : (crackedHit.isNotEmpty
                  ? ChainDropSfxKeys.crackHit
                  : ChainDropSfxKeys.pop),
      );
      notifyListeners();
      await Future.delayed(_flashDelay);

      for (final index in popped) {
        _grid[index] = null;
      }
      for (final index in crackedRemoved) {
        _grid[index] = null;
      }
      _applyGravity();
      notifyListeners();
      await Future.delayed(_gravityDelay);
      round++;
    }
  }

  /// A disc pops when the maximal contiguous run of equal values it belongs
  /// to — in its row, or in its column — has exactly as many discs as its
  /// value. Cracked discs and empty cells always break a run.
  Set<int> _computeNumberedPops() {
    const cols = ChainDropGrid.columns;
    const rows = ChainDropGrid.rows;
    final popped = <int>{};

    for (var row = 0; row < rows; row++) {
      var col = 0;
      while (col < cols) {
        final disc = _grid[row * cols + col];
        if (disc == null || disc.value == null) {
          col++;
          continue;
        }
        final value = disc.value!;
        final start = col;
        while (col < cols && _grid[row * cols + col]?.value == value) {
          col++;
        }
        if (col - start == value) {
          for (var k = start; k < col; k++) {
            popped.add(row * cols + k);
          }
        }
      }
    }

    for (var col = 0; col < cols; col++) {
      var row = 0;
      while (row < rows) {
        final disc = _grid[row * cols + col];
        if (disc == null || disc.value == null) {
          row++;
          continue;
        }
        final value = disc.value!;
        final start = row;
        while (row < rows && _grid[row * cols + col]?.value == value) {
          row++;
        }
        if (row - start == value) {
          for (var k = start; k < row; k++) {
            popped.add(k * cols + col);
          }
        }
      }
    }

    return popped;
  }

  Iterable<int> _neighbors(int index) sync* {
    const cols = ChainDropGrid.columns;
    const rows = ChainDropGrid.rows;
    final row = index ~/ cols;
    final col = index % cols;
    if (row + 1 < rows) yield (row + 1) * cols + col;
    if (row - 1 >= 0) yield (row - 1) * cols + col;
    if (col + 1 < cols) yield row * cols + (col + 1);
    if (col - 1 >= 0) yield row * cols + (col - 1);
  }

  void _applyGravity() {
    const cols = ChainDropGrid.columns;
    const rows = ChainDropGrid.rows;
    for (var col = 0; col < cols; col++) {
      final stack = <ChainDropDisc>[];
      for (var row = 0; row < rows; row++) {
        final disc = _grid[row * cols + col];
        if (disc != null) stack.add(disc);
        _grid[row * cols + col] = null;
      }
      for (var i = 0; i < stack.length; i++) {
        stack[i].row = i;
        _grid[i * cols + col] = stack[i];
      }
    }
  }

  /// Shifts every column up one row and fills the bottom row with fresh
  /// cracked discs. Returns true (and leaves the board untouched) if any
  /// column was already full, which ends the game instead.
  bool _insertGarbageRow() {
    const cols = ChainDropGrid.columns;
    const rows = ChainDropGrid.rows;
    for (var col = 0; col < cols; col++) {
      if (_grid[(rows - 1) * cols + col] != null) return true;
    }
    for (var col = 0; col < cols; col++) {
      for (var row = rows - 1; row >= 1; row--) {
        final disc = _grid[(row - 1) * cols + col];
        if (disc != null) disc.row = row;
        _grid[row * cols + col] = disc;
      }
      _grid[col] = ChainDropDisc(
        id: _nextId++,
        row: 0,
        col: col,
        spawned: true,
      );
    }
    _level++;
    return false;
  }

  void _endGame() {
    _gameOver = true;
    onSfx?.call(ChainDropSfxKeys.gameOver);
  }

  // ---------------------------------------------------------------- persistence

  Future<void> _persist() => _store.writeSave(_serialize());

  Map<String, dynamic> _serialize() => {
    'score': _score,
    'level': _level,
    'dropsSinceGarbage': _dropsSinceGarbage,
    'queue': List<int>.from(_queue),
    'discs': [
      for (final disc in _grid.whereType<ChainDropDisc>())
        {
          'r': disc.row,
          'c': disc.col,
          if (disc.value != null) 'v': disc.value else 'k': disc.crackStage,
        },
    ],
  };

  /// Rebuilds from a save, rejecting anything it cannot trust — an out-of-range
  /// cell, a disc floating above a gap, a queue of the wrong shape — rather
  /// than risking a state legal play could never produce.
  bool _hydrate(Map<String, dynamic> data) {
    final rawDiscs = data['discs'];
    final rawQueue = data['queue'];
    if (rawDiscs is! List || rawDiscs.length > ChainDropGrid.cells) {
      return false;
    }
    if (rawQueue is! List || rawQueue.length != 3) return false;

    final queue = <int>[];
    for (final entry in rawQueue) {
      if (entry is! int || entry < 1 || entry > 7) return false;
      queue.add(entry);
    }

    final grid = List<ChainDropDisc?>.filled(ChainDropGrid.cells, null);
    var nextId = 1;
    for (final entry in rawDiscs) {
      if (entry is! Map) return false;
      final row = entry['r'];
      final col = entry['c'];
      if (row is! int || col is! int) return false;
      if (row < 0 || row >= ChainDropGrid.rows) return false;
      if (col < 0 || col >= ChainDropGrid.columns) return false;
      final index = row * ChainDropGrid.columns + col;
      if (grid[index] != null) return false;

      final value = entry['v'];
      final crack = entry['k'];
      if ((value == null) == (crack == null)) return false;
      if (value != null) {
        if (value is! int || value < 1 || value > 7) return false;
        grid[index] = ChainDropDisc(
          id: nextId++,
          row: row,
          col: col,
          value: value,
        );
      } else {
        if (crack is! int || crack < 0 || crack > 1) return false;
        grid[index] = ChainDropDisc(
          id: nextId++,
          row: row,
          col: col,
          crackStage: crack,
        );
      }
    }

    for (var col = 0; col < ChainDropGrid.columns; col++) {
      var sawGap = false;
      for (var row = 0; row < ChainDropGrid.rows; row++) {
        final occupied = grid[row * ChainDropGrid.columns + col] != null;
        if (!occupied) {
          sawGap = true;
        } else if (sawGap) {
          return false;
        }
      }
    }

    final score = data['score'];
    final level = data['level'];
    final dropsSinceGarbage = data['dropsSinceGarbage'];
    if (score is! int || score < 0) return false;
    if (level is! int || level < 0) return false;
    if (dropsSinceGarbage is! int ||
        dropsSinceGarbage < 0 ||
        dropsSinceGarbage >= ChainDropGrid.dropsPerGarbageRow) {
      return false;
    }

    _score = score;
    _level = level;
    _dropsSinceGarbage = dropsSinceGarbage;
    _queue
      ..clear()
      ..addAll(queue);
    _nextId = nextId;
    for (var i = 0; i < ChainDropGrid.cells; i++) {
      _grid[i] = grid[i];
    }
    _resolving = false;
    _gameOver = _isFull;
    return true;
  }

  Future<void> saveNow() => _persist();
}
