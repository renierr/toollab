import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/tools/chaindrop/engine/chaindrop_engine.dart';
import 'package:tool_lab/tools/chaindrop/engine/chaindrop_store.dart';

class _MemoryStore implements ChainDropStore {
  Map<String, dynamic>? save;
  int best = 0;

  @override
  Future<int> loadBest() async => best;

  @override
  Future<void> saveBest(int value) async => best = value;

  @override
  Future<Map<String, dynamic>?> loadSave() async => save;

  @override
  Future<void> writeSave(Map<String, dynamic> data) async => save = data;

  @override
  Future<void> clearSave() async => save = null;
}

Map<String, dynamic> _saveFor({
  required int level,
  required int dropsSinceGarbage,
}) => {
  'score': 0,
  'level': level,
  'dropsSinceGarbage': dropsSinceGarbage,
  'queue': [7, 6, 5],
  'discs': [],
};

Map<String, dynamic> _saveWithDiscs({
  required List<Map<String, dynamic>> discs,
  List<int> queue = const [7, 6, 5],
  int wildCharges = 0,
}) => {
  'score': 0,
  'level': 0,
  'dropsSinceGarbage': 0,
  'wildCharges': wildCharges,
  'queue': queue,
  'discs': discs,
};

Future<ChainDropEngine> _engineWith({
  required int level,
  required int dropsSinceGarbage,
  bool faithfulRules = false,
}) async {
  final store = _MemoryStore()
    ..save = _saveFor(level: level, dropsSinceGarbage: dropsSinceGarbage);
  final engine = ChainDropEngine(store: store, random: math.Random(7));
  engine.setFaithfulRulesResolver(() => faithfulRules);
  await engine.start();
  return engine;
}

void main() {
  test('crack waves arrive after eight successful drops', () async {
    final engine = await _engineWith(level: 0, dropsSinceGarbage: 7);

    await engine.dropDisc(0);

    expect(engine.level, 1);
    expect(engine.discs.where((disc) => disc.value == null), hasLength(1));
  });

  test('crack waves stay light before capping at three discs', () async {
    final cases = <({int level, int expectedCracks})>[
      (level: 1, expectedCracks: 1),
      (level: 2, expectedCracks: 2),
      (level: 3, expectedCracks: 3),
      (level: 8, expectedCracks: 3),
    ];

    for (final testCase in cases) {
      final engine = await _engineWith(
        level: testCase.level,
        dropsSinceGarbage: 7,
      );

      await engine.dropDisc(0);

      expect(
        engine.discs.where((disc) => disc.value == null),
        hasLength(testCase.expectedCracks),
        reason: 'level ${testCase.level}',
      );
    }
  });

  test('softened crack waves insert their discs at the bottom', () async {
    final engine = await _engineWith(level: 0, dropsSinceGarbage: 7);

    await engine.dropDisc(0);

    final crack = engine.discs.singleWhere((disc) => disc.value == null);
    expect(crack.row, 0);
  });

  test('faithful rules insert a full cracked row at the bottom', () async {
    final engine = await _engineWith(
      level: 0,
      dropsSinceGarbage: 7,
      faithfulRules: true,
    );

    await engine.dropDisc(0);

    final cracks = engine.discs.where((disc) => disc.value == null).toList();
    expect(cracks, hasLength(7));
    expect(cracks.map((disc) => disc.row), everyElement(0));
  });

  test('wild disc charges persist across save and reload', () async {
    final store = _MemoryStore()
      ..save = _saveFor(level: 0, dropsSinceGarbage: 0);
    final engine = ChainDropEngine(store: store, random: math.Random(7));
    await engine.start();

    await engine.usePower(ChainDropPower.wildDisc);
    expect(engine.wildCharges, 1);

    final restored = ChainDropEngine(store: store, random: math.Random(7));
    await restored.start();

    expect(restored.wildCharges, 1);
  });

  test('wild disc power matches the value of an adjacent neighbor', () async {
    final store = _MemoryStore()
      ..save = _saveWithDiscs(
        discs: [
          {'r': 0, 'c': 0, 'v': 3},
        ],
        wildCharges: 1,
      );
    final engine = ChainDropEngine(store: store, random: math.Random(7));
    await engine.start();

    await engine.dropDisc(1);

    final dropped = engine.discs.singleWhere((disc) => disc.col == 1);
    expect(dropped.value, 3);
    expect(engine.wildCharges, 0);
  });

  test('clear column power empties the tallest column', () async {
    final store = _MemoryStore()
      ..save = _saveWithDiscs(
        discs: [
          {'r': 0, 'c': 2, 'v': 4},
          {'r': 1, 'c': 2, 'v': 5},
          {'r': 0, 'c': 5, 'v': 6},
        ],
      );
    final engine = ChainDropEngine(store: store, random: math.Random(7));
    await engine.start();

    await engine.usePower(ChainDropPower.clearColumn);

    expect(engine.discs.where((disc) => disc.col == 2), isEmpty);
    expect(engine.discs.where((disc) => disc.col == 5), hasLength(1));
  });

  test('defuse power removes the most-cracked disc on the board', () async {
    final store = _MemoryStore()
      ..save = _saveWithDiscs(
        discs: [
          {'r': 0, 'c': 0, 'k': 0},
          {'r': 0, 'c': 3, 'k': 1},
        ],
      );
    final engine = ChainDropEngine(store: store, random: math.Random(7));
    await engine.start();

    await engine.usePower(ChainDropPower.defuse);

    expect(engine.discs.where((disc) => disc.col == 3), isEmpty);
    expect(engine.discs.where((disc) => disc.col == 0), hasLength(1));
  });

  test('reroll power replaces every queued value', () async {
    final engine = await _engineWith(level: 0, dropsSinceGarbage: 0);
    final before = List<int>.from(engine.queue);

    await engine.usePower(ChainDropPower.reroll);

    expect(engine.queue, isNot(equals(before)));
    expect(engine.queue, hasLength(3));
  });

  test(
    'undo restores the exact board, score, and queue before a drop',
    () async {
      final engine = await _engineWith(level: 0, dropsSinceGarbage: 0);
      final queueBefore = List<int>.from(engine.queue);
      final discsBefore = engine.discs.length;

      await engine.dropDisc(0);
      expect(engine.discs.length, discsBefore + 1);

      engine.undoMove();

      expect(engine.discs.length, discsBefore);
      expect(engine.queue, queueBefore);
      expect(engine.score, 0);
    },
  );
}
