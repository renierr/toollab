import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/tools/luma_well/engine/luma_well_engine.dart';
import 'package:tool_lab/tools/luma_well/engine/luma_well_store.dart';

void main() {
  test('starts with slowly drifting matter around a small planet', () async {
    final engine = LumaWellEngine(
      store: _MemoryStore(),
      random: _FixedRandom(),
    );
    await engine.start();

    expect(engine.orbs, hasLength(18));
    expect(engine.planetRadius, lessThan(0.11));
  });

  test('a capture ring selects only matching nearby kinds', () async {
    final engine = LumaWellEngine(
      store: _MemoryStore(),
      random: _FixedRandom(),
    );
    await engine.start();

    engine.beginCapture(0.42, 0);

    expect(engine.capturedIds.length, greaterThanOrEqualTo(2));
  });

  test('holding a valid capture grows the planet', () async {
    final engine = LumaWellEngine(
      store: _MemoryStore(),
      random: _FixedRandom(),
    );
    await engine.start();
    final before = engine.planetRadius;
    engine.beginCapture(0.42, 0);

    for (var i = 0; i < 70; i++) {
      engine.advance(0.04);
    }

    expect(engine.merges, 1);
    expect(engine.planetRadius, greaterThan(before));
  });

  test('powers use an earned charge', () async {
    final engine = LumaWellEngine(store: _MemoryStore(), random: Random(1));
    await engine.start();

    engine.usePower(LumaWellPower.stabilize);

    expect(engine.powerCharges, 0);
  });
}

class _MemoryStore extends LumaWellStore {
  @override
  Future<int> loadBest() async => 0;

  @override
  Future<void> saveBest(int value) async {}
}

class _FixedRandom implements Random {
  int _index = 0;

  @override
  bool nextBool() => false;

  @override
  double nextDouble() => (_index++ % 3) * 0.01;

  @override
  int nextInt(int max) => _index++ % max;
}
