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

Future<ChainDropEngine> _engineWith({
  required int level,
  required int dropsSinceGarbage,
}) async {
  final store = _MemoryStore()
    ..save = _saveFor(level: level, dropsSinceGarbage: dropsSinceGarbage);
  final engine = ChainDropEngine(store: store, random: math.Random(7));
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
}
