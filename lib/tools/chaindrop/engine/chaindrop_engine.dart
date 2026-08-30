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

  /// Successful drops between cracked-disc waves.
  static const int dropsPerCrackWave = 6;
}

/// Sound/haptic event keys the engine fires mid-resolution. Kept as plain
/// strings with no audio dependency, so the engine never imports SoLoud.
class ChainDropSfxKeys {
  ChainDropSfxKeys._();

  static const String drop = 'drop';
  static const String pop = 'pop';
  static const String crackHit = 'crack_hit';
  static const String crackBreak = 'crack_break';
  static const String crackWave = 'crack_wave';
  static const String gameOver = 'game_over';
}

/// The free, unlimited-use assists reachable from the power menu.
enum ChainDropPower { clearColumn, defuse, reroll, wildDisc }

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
/// the escalating cracked-disc waves.
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

  final List<_Snapshot> _history = [];

  int _nextId = 1;
  int _score = 0;
  int _best = 0;
  int _level = 0;
  int _dropsSinceGarbage = 0;
  int _wildCharges = 0;
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
  int get wildCharges => _wildCharges;
  bool get isResolving => _resolving;
  bool get isGameOver => _gameOver;
  bool get canUndo => _history.isNotEmpty;
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
    _wildCharges = 0;
    _resolving = false;
    _gameOver = false;
    _history.clear();
    _queue
      ..clear()
      ..addAll([_randomValue(), _randomValue(), _randomValue()]);
  }

  int _randomValue() => _random.nextInt(7) + 1;

  // ----------------------------------------------------------------------- play

  /// Drops the front of the queue into [column], then resolves every cascade
  /// round it triggers (and a wave of cracked discs, if this drop crosses the
  /// counter). Returns false without effect if the column is full, a drop is
  /// already resolving, or the game has ended.
  Future<bool> dropDisc(int column) async {
    if (_gameOver || _resolving || isColumnFull(column)) return false;

    _history.add(_capture());
    _resolving = true;
    _clearTransientFlags();
    final value = _queue.removeAt(0);
    _queue.add(_randomValue());
    final row = _columnHeight(column);
    final index = row * ChainDropGrid.columns + column;
    final disc = ChainDropDisc(
      id: _nextId++,
      row: row,
      col: column,
      value: value,
      spawned: true,
    );
    _grid[index] = disc;
    if (_wildCharges > 0) {
      _wildCharges--;
      final matched = _matchingNeighborValue(index);
      if (matched != null) disc.value = matched;
    }
    _dropsSinceGarbage++;
    onSfx?.call(ChainDropSfxKeys.drop);
    notifyListeners();
    await Future.delayed(_dropDelay);

    await _resolveCascade();

    if (!_gameOver && _dropsSinceGarbage >= ChainDropGrid.dropsPerCrackWave) {
      _dropsSinceGarbage = 0;
      _clearTransientFlags();
      _insertCrackedWave();
      onSfx?.call(ChainDropSfxKeys.crackWave);
      notifyListeners();
      await Future.delayed(_dropDelay);
      await _resolveCascade();
    }

    if (!_gameOver && _isFull) {
      _endGame();
    }

    _resolving = false;
    unawaited(_persist());
    notifyListeners();
    return true;
  }

  /// Reverts the board to how it looked before the last completed drop
  /// (including any cascade and any cracked-disc wave it triggered).
  void undoMove() {
    if (_resolving || _history.isEmpty) return;
    _restore(_history.removeLast());
    _gameOver = false;
    unawaited(_persist());
    notifyListeners();
  }

  int? _matchingNeighborValue(int index) {
    for (final neighbor in _neighbors(index)) {
      final value = _grid[neighbor]?.value;
      if (value != null) return value;
    }
    return null;
  }

  // --------------------------------------------------------------- power-ups

  /// Applies a free, unlimited-use assist from the power menu. A no-op if the
  /// board has nothing for it to act on (an empty board for [ChainDropPower.
  /// clearColumn], no cracked discs for [ChainDropPower.defuse]).
  Future<void> usePower(ChainDropPower power) async {
    if (_gameOver || _resolving) return;
    switch (power) {
      case ChainDropPower.clearColumn:
        await _useClearColumn();
      case ChainDropPower.defuse:
        await _useDefuse();
      case ChainDropPower.reroll:
        _useReroll();
      case ChainDropPower.wildDisc:
        _wildCharges++;
        notifyListeners();
    }
    unawaited(_persist());
  }

  Future<void> _useClearColumn() async {
    final column = _tallestColumn();
    if (column == null) return;

    _resolving = true;
    _clearTransientFlags();
    for (var row = 0; row < ChainDropGrid.rows; row++) {
      _grid[row * ChainDropGrid.columns + column] = null;
    }
    notifyListeners();
    await Future.delayed(_gravityDelay);
    await _resolveCascade();
    if (!_gameOver && _isFull) _endGame();
    _resolving = false;
    notifyListeners();
  }

  Future<void> _useDefuse() async {
    int? target;
    var bestStage = -1;
    for (var i = 0; i < ChainDropGrid.cells; i++) {
      final disc = _grid[i];
      if (disc == null || disc.value != null) continue;
      if (disc.crackStage > bestStage) {
        bestStage = disc.crackStage;
        target = i;
      }
    }
    if (target == null) return;

    _resolving = true;
    _clearTransientFlags();
    _grid[target] = null;
    _applyGravity();
    notifyListeners();
    await Future.delayed(_gravityDelay);
    await _resolveCascade();
    if (!_gameOver && _isFull) _endGame();
    _resolving = false;
    notifyListeners();
  }

  void _useReroll() {
    for (var i = 0; i < _queue.length; i++) {
      _queue[i] = _randomValue();
    }
    notifyListeners();
  }

  int? _tallestColumn() {
    var best = -1;
    var bestHeight = 0;
    for (var col = 0; col < ChainDropGrid.columns; col++) {
      final height = _columnHeight(col);
      if (height > bestHeight) {
        bestHeight = height;
        best = col;
      }
    }
    return best == -1 ? null : best;
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

  /// Scatters fresh cracked discs into random columns that still have room,
  /// one per column, dropped onto each column's current stack rather than
  /// shoving the whole board up. The wave grows with [_level] — the Nth wave
  /// wants N discs, capped by however many columns are actually free.
  void _insertCrackedWave() {
    _level++;
    final available = <int>[
      for (var col = 0; col < ChainDropGrid.columns; col++)
        if (!isColumnFull(col)) col,
    ];
    available.shuffle(_random);
    final count = math.min(_level, available.length);
    for (var i = 0; i < count; i++) {
      final col = available[i];
      final row = _columnHeight(col);
      _grid[row * ChainDropGrid.columns + col] = ChainDropDisc(
        id: _nextId++,
        row: row,
        col: col,
        spawned: true,
      );
    }
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
        dropsSinceGarbage >= ChainDropGrid.dropsPerCrackWave) {
      return false;
    }

    _score = score;
    _level = level;
    _dropsSinceGarbage = dropsSinceGarbage;
    _wildCharges = 0;
    _history.clear();
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

  // --------------------------------------------------------------------- undo

  /// A cell packs to 0 (empty), a positive 1-7 (numbered disc), or a negative
  /// `-(crackStage + 1)` (cracked disc) — one flat int list, no object graph.
  _Snapshot _capture() => _Snapshot(
    score: _score,
    level: _level,
    dropsSinceGarbage: _dropsSinceGarbage,
    wildCharges: _wildCharges,
    queue: List<int>.from(_queue),
    cells: [
      for (final disc in _grid)
        if (disc == null)
          0
        else if (disc.value != null)
          disc.value!
        else
          -(disc.crackStage + 1),
    ],
  );

  void _restore(_Snapshot snapshot) {
    _score = snapshot.score;
    _level = snapshot.level;
    _dropsSinceGarbage = snapshot.dropsSinceGarbage;
    _wildCharges = snapshot.wildCharges;
    _queue
      ..clear()
      ..addAll(snapshot.queue);
    for (var i = 0; i < ChainDropGrid.cells; i++) {
      final packed = snapshot.cells[i];
      if (packed == 0) {
        _grid[i] = null;
      } else if (packed > 0) {
        _grid[i] = ChainDropDisc(
          id: _nextId++,
          row: i ~/ ChainDropGrid.columns,
          col: i % ChainDropGrid.columns,
          value: packed,
        );
      } else {
        _grid[i] = ChainDropDisc(
          id: _nextId++,
          row: i ~/ ChainDropGrid.columns,
          col: i % ChainDropGrid.columns,
          crackStage: -packed - 1,
        );
      }
    }
  }
}

class _Snapshot {
  final int score;
  final int level;
  final int dropsSinceGarbage;
  final int wildCharges;
  final List<int> queue;
  final List<int> cells;

  const _Snapshot({
    required this.score,
    required this.level,
    required this.dropsSinceGarbage,
    required this.wildCharges,
    required this.queue,
    required this.cells,
  });
}
