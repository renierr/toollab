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

  test('a capture fails when visible values span more than one', () async {
    final engine = LumaWellEngine(
      store: _MemoryStore()
        ..save = _savedField([
          {'mass': 1.0, 'kind': 0, 'x': 0.42, 'y': 0.0, 'drift': 0.0},
          {'mass': 1.0, 'kind': 2, 'x': 0.44, 'y': 0.0, 'drift': 0.0},
        ]),
    );
    await engine.start();

    engine.beginCapture(0.42, 0);

    expect(engine.captureBlocked, isTrue);
    expect(engine.capturedIds, isEmpty);
  });

  test('a power orb joins a valid pair and awards a power charge', () async {
    final engine = LumaWellEngine(
      store: _MemoryStore()
        ..save = _savedField([
          {'mass': 1.0, 'kind': 0, 'x': 0.42, 'y': 0.0, 'drift': 0.0},
          {'mass': 1.0, 'kind': 1, 'x': 0.44, 'y': 0.0, 'drift': 0.0},
          {
            'mass': 1.0,
            'kind': 3,
            'power': true,
            'x': 0.46,
            'y': 0.0,
            'drift': 0.0,
          },
        ]),
    );
    await engine.start();
    engine.usePower(LumaWellPower.stabilize);
    engine.beginCapture(0.42, 0);

    for (var i = 0; i < 42; i++) {
      engine.advance(0.04);
    }

    expect(engine.merges, 1);
    expect(engine.powerCharges, 1);
  });

  test(
    'an invalid group cannot complete if its capture state is stale',
    () async {
      final engine = LumaWellEngine(
        store: _MemoryStore()
          ..save = _savedField([
            {'mass': 1.0, 'kind': 0, 'x': 0.42, 'y': 0.0, 'drift': 0.0},
            {'mass': 1.0, 'kind': 2, 'x': 0.44, 'y': 0.0, 'drift': 0.0},
          ]),
      );
      await engine.start();
      engine.beginCapture(0.42, 0);

      for (var i = 0; i < 42; i++) {
        engine.advance(0.04);
      }

      expect(engine.merges, 0);
    },
  );

  test('holding a valid capture grows the planet', () async {
    final engine = LumaWellEngine(
      store: _MemoryStore(),
      random: _FixedRandom(),
    );
    await engine.start();
    final before = engine.planetRadius;
    engine.beginCapture(0.42, 0);

    for (var i = 0; i < 42; i++) {
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

  test('restores a saved planet and its field', () async {
    final store = _MemoryStore()
      ..save = {
        'score': 41,
        'merges': 3,
        'stage': 2,
        'charges': 1,
        'planetMass': 35.0,
        'wideCaptures': 2,
        'orbs': [
          {'mass': 2.0, 'kind': 0, 'x': 0.5, 'y': 0.0, 'drift': 0.1},
        ],
      };
    final engine = LumaWellEngine(store: store);

    await engine.start();

    expect(engine.score, 41);
    expect(engine.stage, 2);
    expect(engine.orbs, hasLength(1));
  });

  test('saveNow preserves the current run for a future engine', () async {
    final store = _MemoryStore();
    final first = LumaWellEngine(store: store, random: Random(1));
    await first.start();
    first.usePower(LumaWellPower.stabilize);
    await first.saveNow();
    final restored = LumaWellEngine(store: store);

    await restored.start();

    expect(restored.orbs.length, first.orbs.length);
    expect(restored.powerCharges, first.powerCharges);
  });
}

class _MemoryStore extends LumaWellStore {
  Map<String, dynamic>? save;

  @override
  Future<int> loadBest() async => 0;

  @override
  Future<void> saveBest(int value) async {}

  @override
  Future<Map<String, dynamic>?> loadSave() async => save;

  @override
  Future<void> writeSave(Map<String, dynamic> value) async => save = value;
}

Map<String, dynamic> _savedField(List<Map<String, dynamic>> orbs) => {
  'score': 0,
  'merges': 0,
  'stage': 1,
  'charges': 1,
  'planetMass': 4.0,
  'wideCaptures': 0,
  'orbs': orbs,
};

class _FixedRandom implements Random {
  int _index = 0;

  @override
  bool nextBool() => false;

  @override
  double nextDouble() => (_index++ % 3) * 0.01;

  @override
  int nextInt(int max) => _index++ % max;
}
