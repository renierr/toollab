import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'twenty48_direction.dart';
import 'twenty48_store.dart';

/// The grid's fixed logical size. Four columns is the game; changing it would
/// change what 2048 *is*, so these are constants and not options.
class Twenty48Grid {
  Twenty48Grid._();

  static const int size = 4;
  static const int cells = size * size;

  /// The tile that wins the run. Reaching it does not end the game — the
  /// player may keep merging for a higher score.
  static const int target = 2048;

  /// Beyond this a value cannot be reached by legal play, so a save claiming
  /// one has been hand-edited.
  static const int maxValue = 1 << 17;
}

/// One tile on the board.
///
/// The [id] is what lets the view keep one element attached to the same tile
/// as it slides, so the slide is an implicit animation between two builds
/// rather than something the engine has to drive.
class Twenty48Tile {
  final int id;
  int value;
  int row;
  int col;

  /// Appeared this move — the view scales it in rather than sliding it.
  bool spawned;

  /// Absorbed another tile this move — the view pops it.
  bool merged;

  /// Was absorbed *into* another tile this move. Kept for one move so it can
  /// finish sliding under its survivor, then dropped.
  bool absorbed;

  Twenty48Tile({
    required this.id,
    required this.value,
    required this.row,
    required this.col,
    this.spawned = false,
    this.merged = false,
    this.absorbed = false,
  });
}

/// 2048's simulation.
///
/// A turn-based game, so there is no frame loop: state changes only on a move
/// and the view rebuilds from [ChangeNotifier].
class Twenty48Engine extends ChangeNotifier {
  final Twenty48Store _store;
  final math.Random _random;

  /// Source of truth: one slot per cell, row-major. [tiles] is derived from it.
  final List<Twenty48Tile?> _grid = List<Twenty48Tile?>.filled(
    Twenty48Grid.cells,
    null,
  );

  final List<Twenty48Tile> _absorbed = [];

  int _nextId = 1;
  int _score = 0;
  int _best = 0;
  int _moves = 0;
  bool _won = false;
  bool _stuck = false;
  int _lastMergedValue = 0;

  final List<_Snapshot> _history = [];

  Twenty48Engine({Twenty48Store? store, math.Random? random})
    : _store = store ?? const Twenty48Store(),
      _random = random ?? math.Random();

  int get score => _score;
  int get best => _best;
  int get moves => _moves;

  /// True once a 2048 tile exists, and stays true for the rest of the run.
  bool get won => _won;

  /// No legal move remains.
  bool get isStuck => _stuck;

  bool get canUndo => _history.isNotEmpty;

  /// The largest value produced by the last move's merges, or 0 if it merged
  /// nothing. The page pitches its merge sound from this.
  int get lastMergedValue => _lastMergedValue;

  /// Every tile the view should draw, absorbed ones first so a survivor paints
  /// over the tile it just swallowed.
  List<Twenty48Tile> get tiles => [
    ..._absorbed,
    ..._grid.whereType<Twenty48Tile>(),
  ];

  int get highestValue =>
      _grid.whereType<Twenty48Tile>().fold(0, (m, t) => math.max(m, t.value));

  // ------------------------------------------------------------------ lifecycle

  /// Restores the saved run, or deals a fresh board when there is nothing
  /// trustworthy to restore.
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
    _grid.fillRange(0, Twenty48Grid.cells, null);
    _absorbed.clear();
    _score = 0;
    _moves = 0;
    _won = false;
    _stuck = false;
    _lastMergedValue = 0;
    _history.clear();
    _spawn();
    _spawn();
  }

  // ----------------------------------------------------------------------- play

  /// Slides every tile as far as it will go and merges equal pairs.
  ///
  /// Returns whether anything actually moved: a swipe into a wall is not a
  /// turn, so it must not spawn a tile or cost the player their undo.
  bool move(Twenty48Direction direction) {
    if (_stuck) return false;

    final snapshot = _capture();
    _absorbed.clear();
    _lastMergedValue = 0;
    for (final tile in _grid.whereType<Twenty48Tile>()) {
      tile.spawned = false;
      tile.merged = false;
    }

    if (!_slide(direction)) return false;

    _history.add(snapshot);
    _moves++;
    _spawn();
    if (_score > _best) {
      _best = _score;
      unawaited(_store.saveBest(_best));
    }
    if (!_won && highestValue >= Twenty48Grid.target) _won = true;
    _stuck = !_hasMove();
    unawaited(_persist());
    notifyListeners();
    return true;
  }

  void undoMove() {
    if (_history.isEmpty) return;
    _restore(_history.removeLast());
    _lastMergedValue = 0;
    unawaited(_persist());
    notifyListeners();
  }

  bool _slide(Twenty48Direction direction) {
    var moved = false;
    for (final line in _linesFacing(direction)) {
      // Everything in the line, ordered from the wall it is sliding towards.
      final incoming = [
        for (final index in line)
          if (_grid[index] != null) _grid[index]!,
      ];
      for (final index in line) {
        _grid[index] = null;
      }

      var slot = 0;
      Twenty48Tile? previous;
      var previousMerged = false;

      for (final tile in incoming) {
        if (previous != null &&
            !previousMerged &&
            previous.value == tile.value) {
          previous.value *= 2;
          previous.merged = true;
          _score += previous.value;
          _lastMergedValue = math.max(_lastMergedValue, previous.value);
          // The absorbed tile finishes its slide into the survivor's cell,
          // which is what makes a merge read as two tiles colliding.
          tile.row = previous.row;
          tile.col = previous.col;
          tile.absorbed = true;
          _absorbed.add(tile);
          previousMerged = true;
          moved = true;
          continue;
        }
        final index = line[slot];
        final row = index ~/ Twenty48Grid.size;
        final col = index % Twenty48Grid.size;
        if (tile.row != row || tile.col != col) moved = true;
        tile.row = row;
        tile.col = col;
        _grid[index] = tile;
        previous = tile;
        previousMerged = false;
        slot++;
      }
    }
    return moved;
  }

  /// Cell indices grouped into the four rows or columns, each ordered from the
  /// wall the tiles are sliding towards — so a single forward walk per line
  /// resolves the whole move.
  List<List<int>> _linesFacing(Twenty48Direction direction) {
    const n = Twenty48Grid.size;
    final lines = <List<int>>[];
    for (var i = 0; i < n; i++) {
      final line = <int>[];
      for (var j = 0; j < n; j++) {
        switch (direction) {
          case Twenty48Direction.left:
            line.add(i * n + j);
          case Twenty48Direction.right:
            line.add(i * n + (n - 1 - j));
          case Twenty48Direction.up:
            line.add(j * n + i);
          case Twenty48Direction.down:
            line.add((n - 1 - j) * n + i);
        }
      }
      lines.add(line);
    }
    return lines;
  }

  void _spawn() {
    final free = <int>[];
    for (var i = 0; i < Twenty48Grid.cells; i++) {
      if (_grid[i] == null) free.add(i);
    }
    if (free.isEmpty) return;
    final index = free[_random.nextInt(free.length)];
    _grid[index] = Twenty48Tile(
      id: _nextId++,
      // The classic one-in-ten 4: frequent enough to break up a clean board,
      // rare enough that it is bad luck rather than the norm.
      value: _random.nextInt(10) == 0 ? 4 : 2,
      row: index ~/ Twenty48Grid.size,
      col: index % Twenty48Grid.size,
      spawned: true,
    );
  }

  bool _hasMove() {
    const n = Twenty48Grid.size;
    for (var i = 0; i < Twenty48Grid.cells; i++) {
      final tile = _grid[i];
      if (tile == null) return true;
      final row = i ~/ n;
      final col = i % n;
      // Only right and down: a matching pair is symmetric, so checking two
      // directions covers all four.
      if (col + 1 < n && _grid[i + 1]?.value == tile.value) return true;
      if (row + 1 < n && _grid[i + n]?.value == tile.value) return true;
    }
    return false;
  }

  // ---------------------------------------------------------------- persistence

  Future<void> _persist() => _store.writeSave(_serialize());

  Map<String, dynamic> _serialize() => {
    'score': _score,
    'moves': _moves,
    'won': _won,
    'tiles': [
      for (final tile in _grid.whereType<Twenty48Tile>())
        {'r': tile.row, 'c': tile.col, 'v': tile.value},
    ],
  };

  /// Rebuilds from a save, rejecting anything it cannot trust rather than
  /// trusting the blob: a hand-edited file must not be able to seed a value
  /// legal play could never produce, or two tiles in one cell.
  bool _hydrate(Map<String, dynamic> data) {
    final raw = data['tiles'];
    if (raw is! List || raw.isEmpty || raw.length > Twenty48Grid.cells) {
      return false;
    }

    final grid = List<Twenty48Tile?>.filled(Twenty48Grid.cells, null);
    var nextId = 1;
    for (final entry in raw) {
      if (entry is! Map) return false;
      final row = entry['r'];
      final col = entry['c'];
      final value = entry['v'];
      if (row is! int || col is! int || value is! int) return false;
      if (row < 0 || row >= Twenty48Grid.size) return false;
      if (col < 0 || col >= Twenty48Grid.size) return false;
      if (!_isLegalValue(value)) return false;
      final index = row * Twenty48Grid.size + col;
      if (grid[index] != null) return false;
      grid[index] = Twenty48Tile(
        id: nextId++,
        value: value,
        row: row,
        col: col,
      );
    }

    final score = data['score'];
    final moves = data['moves'];
    _score = score is int && score >= 0 ? score : 0;
    _moves = moves is int && moves >= 0 ? moves : 0;
    _won = data['won'] == true;
    _nextId = nextId;
    _absorbed.clear();
    _history.clear();
    for (var i = 0; i < Twenty48Grid.cells; i++) {
      _grid[i] = grid[i];
    }
    _stuck = !_hasMove();
    return true;
  }

  static bool _isLegalValue(int value) =>
      value >= 2 && value <= Twenty48Grid.maxValue && value & (value - 1) == 0;

  // --------------------------------------------------------------------- undo

  _Snapshot _capture() => _Snapshot(
    score: _score,
    moves: _moves,
    won: _won,
    cells: [
      for (final tile in _grid)
        if (tile == null) 0 else tile.value,
    ],
  );

  void _restore(_Snapshot snapshot) {
    _absorbed.clear();
    _score = snapshot.score;
    _moves = snapshot.moves;
    _won = snapshot.won;
    for (var i = 0; i < Twenty48Grid.cells; i++) {
      final value = snapshot.cells[i];
      _grid[i] = value == 0
          ? null
          : Twenty48Tile(
              id: _nextId++,
              value: value,
              row: i ~/ Twenty48Grid.size,
              col: i % Twenty48Grid.size,
            );
    }
    _stuck = !_hasMove();
  }

  Future<void> saveNow() => _persist();
}

class _Snapshot {
  final int score;
  final int moves;
  final bool won;
  final List<int> cells;

  const _Snapshot({
    required this.score,
    required this.moves,
    required this.won,
    required this.cells,
  });
}
