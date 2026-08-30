import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/tools/twenty48/engine/twenty48_direction.dart';
import 'package:tool_lab/tools/twenty48/engine/twenty48_engine.dart';
import 'package:tool_lab/tools/twenty48/engine/twenty48_store.dart';

/// Stands in for the database, so these tests never touch one.
class _MemoryStore implements Twenty48Store {
  Map<String, dynamic>? save;
  int best = 0;
  int writes = 0;

  @override
  Future<int> loadBest() async => best;

  @override
  Future<void> saveBest(int value) async => best = value;

  @override
  Future<Map<String, dynamic>?> loadSave() async => save;

  @override
  Future<void> writeSave(Map<String, dynamic> data) async {
    save = data;
    writes++;
  }

  @override
  Future<void> clearSave() async => save = null;
}

/// Builds a save blob for a board written out as rows of values, 0 for empty.
/// Crafting the board directly is the only way to test the merge rules without
/// fighting the random spawn.
Map<String, dynamic> _saveFor(List<List<int>> rows, {int score = 0}) => {
  'score': score,
  'moves': 0,
  'won': false,
  'tiles': [
    for (var r = 0; r < rows.length; r++)
      for (var c = 0; c < rows[r].length; c++)
        if (rows[r][c] != 0) {'r': r, 'c': c, 'v': rows[r][c]},
  ],
};

/// The board as a plain grid of values, for assertions.
List<List<int>> _grid(Twenty48Engine engine) {
  final rows = [
    for (var r = 0; r < Twenty48Grid.size; r++)
      List<int>.filled(Twenty48Grid.size, 0),
  ];
  for (final tile in engine.tiles) {
    if (tile.absorbed) continue;
    rows[tile.row][tile.col] = tile.value;
  }
  return rows;
}

Future<Twenty48Engine> _engineWith(
  List<List<int>> rows, {
  int score = 0,
  int seed = 7,
}) async {
  final store = _MemoryStore()..save = _saveFor(rows, score: score);
  final engine = Twenty48Engine(store: store, random: math.Random(seed));
  await engine.start();
  return engine;
}

void main() {
  test('a fresh board deals exactly two legal tiles', () async {
    final engine = Twenty48Engine(
      store: _MemoryStore(),
      random: math.Random(1),
    );
    await engine.start();

    final tiles = engine.tiles;
    expect(tiles.length, 2);
    for (final tile in tiles) {
      expect(tile.value, anyOf(2, 4));
    }
    expect(engine.score, 0);
    expect(engine.isStuck, isFalse);
  });

  test('sliding merges a matching pair once and scores it', () async {
    final engine = await _engineWith([
      [2, 2, 0, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
    ]);

    expect(engine.move(Twenty48Direction.left), isTrue);
    expect(_grid(engine)[0][0], 4);
    expect(engine.score, 4);
    expect(engine.lastMergedValue, 4);
  });

  test('a row of four merges into two pairs, not one chain', () async {
    // The classic rule: 2 2 2 2 becomes 4 4, never a single 8. Chaining would
    // make the whole game trivially winnable.
    final engine = await _engineWith([
      [2, 2, 2, 2],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
    ]);

    engine.move(Twenty48Direction.left);
    final row = _grid(engine)[0];
    expect(row[0], 4);
    expect(row[1], 4);
    expect(engine.score, 8);
  });

  test('three in a line merges only the pair nearest the wall', () async {
    final engine = await _engineWith([
      [2, 2, 2, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
    ]);

    engine.move(Twenty48Direction.left);
    final row = _grid(engine)[0];
    expect(row[0], 4);
    expect(row[1], 2);
  });

  test('a move that changes nothing is refused', () async {
    final engine = await _engineWith([
      [2, 0, 0, 0],
      [4, 0, 0, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
    ]);
    final before = _grid(engine);

    // Everything is already as far left as it goes and nothing can merge, so
    // this must not spawn a tile or count as a turn.
    expect(engine.move(Twenty48Direction.left), isFalse);
    expect(_grid(engine), before);
    expect(engine.moves, 0);
  });

  test('undo restores the board and the score across multiple steps', () async {
    final engine = await _engineWith([
      [2, 2, 0, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
    ]);
    expect(engine.canUndo, isFalse);

    engine.move(Twenty48Direction.left);
    expect(engine.score, 4);
    expect(engine.moves, 1);
    expect(engine.canUndo, isTrue);

    engine.move(Twenty48Direction.down);
    expect(engine.moves, 2);
    expect(engine.canUndo, isTrue);

    engine.undoMove();
    expect(engine.moves, 1);
    expect(engine.score, 4);
    expect(engine.canUndo, isTrue);

    engine.undoMove();
    expect(engine.moves, 0);
    expect(engine.score, 0);
    expect(_grid(engine)[0][0], 2);
    expect(_grid(engine)[0][1], 2);
    expect(engine.canUndo, isFalse);
  });

  test('reaching the target wins without ending the run', () async {
    final engine = await _engineWith([
      [1024, 1024, 0, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
    ]);

    expect(engine.won, isFalse);
    engine.move(Twenty48Direction.left);
    expect(engine.won, isTrue);
    expect(engine.isStuck, isFalse);
    expect(engine.highestValue, 2048);
  });

  test('a full board with no pairs is stuck', () async {
    final engine = await _engineWith([
      [2, 4, 2, 4],
      [4, 2, 4, 2],
      [2, 4, 2, 4],
      [4, 2, 4, 2],
    ]);

    expect(engine.isStuck, isTrue);
    expect(engine.move(Twenty48Direction.left), isFalse);
  });

  test('a full board that can still merge is not stuck', () async {
    final engine = await _engineWith([
      [2, 2, 2, 4],
      [4, 2, 4, 2],
      [2, 4, 2, 4],
      [4, 2, 4, 2],
    ]);

    expect(engine.isStuck, isFalse);
  });

  group('a hand-edited save is rejected rather than trusted', () {
    Future<Twenty48Engine> engineForSave(Map<String, dynamic> save) async {
      final store = _MemoryStore()..save = save;
      final engine = Twenty48Engine(store: store, random: math.Random(3));
      await engine.start();
      return engine;
    }

    test('a value legal play cannot produce', () async {
      final engine = await engineForSave({
        'score': 10,
        'tiles': [
          {'r': 0, 'c': 0, 'v': 6},
        ],
      });
      // Fell back to a fresh deal: two tiles, no score.
      expect(engine.tiles.length, 2);
      expect(engine.score, 0);
    });

    test('a cell off the board', () async {
      final engine = await engineForSave({
        'tiles': [
          {'r': 9, 'c': 0, 'v': 2},
        ],
      });
      expect(engine.tiles.length, 2);
    });

    test('two tiles in one cell', () async {
      final engine = await engineForSave({
        'tiles': [
          {'r': 1, 'c': 1, 'v': 2},
          {'r': 1, 'c': 1, 'v': 4},
        ],
      });
      expect(engine.tiles.length, 2);
    });

    test('a legal save is kept', () async {
      final engine = await engineForSave({
        'score': 12,
        'moves': 3,
        'tiles': [
          {'r': 1, 'c': 1, 'v': 8},
          {'r': 2, 'c': 3, 'v': 16},
        ],
      });
      expect(engine.score, 12);
      expect(engine.moves, 3);
      expect(engine.highestValue, 16);
    });
  });

  test('a move persists the board and a new best score', () async {
    final store = _MemoryStore()
      ..save = _saveFor([
        [2, 2, 0, 0],
        [0, 0, 0, 0],
        [0, 0, 0, 0],
        [0, 0, 0, 0],
      ]);
    final engine = Twenty48Engine(store: store, random: math.Random(5));
    await engine.start();

    engine.move(Twenty48Direction.left);
    expect(store.writes, greaterThan(0));
    expect(store.best, 4);
    expect(store.save?['score'], 4);
  });

  test('absorbed tiles are dropped on the next move', () async {
    final engine = await _engineWith([
      [2, 2, 0, 0],
      [8, 0, 0, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
    ]);

    engine.move(Twenty48Direction.left);
    // The swallowed tile lingers for one move so it can finish sliding under
    // its survivor.
    expect(engine.tiles.where((t) => t.absorbed), isNotEmpty);

    engine.move(Twenty48Direction.down);
    expect(engine.tiles.where((t) => t.absorbed), isEmpty);
  });
}
