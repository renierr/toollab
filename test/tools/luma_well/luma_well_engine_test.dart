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
    expect(engine.lastPowerOrbEffect, LumaWellPowerOrbEffect.charge);
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

  test('higher visible values earn more from the same group size', () async {
    final low = await _capturePair(0);
    final high = await _capturePair(3);

    expect(high.score, greaterThan(low.score));
  });

  test('unlocks values through six by stage five', () async {
    final first = LumaWellEngine(store: _MemoryStore());
    await first.start();
    final fifth = LumaWellEngine(
      store: _MemoryStore()
        ..save = {
          'score': 0,
          'merges': 0,
          'stage': 5,
          'charges': 1,
          'planetMass': 116.0,
          'expandedCaptures': 0,
          'focusedCaptures': 0,
          'orbs': [
            {'mass': 1.0, 'kind': 5, 'x': 0.5, 'y': 0.0, 'drift': 0.0},
          ],
        },
    );
    await fifth.start();

    expect(first.highestUnlockedNumber, 2);
    expect(fifth.highestUnlockedNumber, 6);
  });

  test('powers use an earned charge', () async {
    final engine = LumaWellEngine(store: _MemoryStore(), random: Random(1));
    await engine.start();

    engine.usePower(LumaWellPower.stabilize);

    expect(engine.powerCharges, 0);
  });

  test('unlimited powers do not consume a charge', () async {
    final engine = LumaWellEngine(store: _MemoryStore());
    engine.setUnlimitedPowersResolver(() => true);
    await engine.start();

    engine.usePower(LumaWellPower.stabilize);

    expect(engine.powerCharges, 1);
  });

  test('capture field powers modify the next three rings', () async {
    final engine = LumaWellEngine(store: _MemoryStore());
    engine.setUnlimitedPowersResolver(() => true);
    await engine.start();

    engine.usePower(LumaWellPower.expandField);

    expect(engine.expandedCaptures, 3);
    expect(engine.captureRadius, 0.31);
    engine.usePower(LumaWellPower.focusField);
    expect(engine.focusedCaptures, 3);
  });

  test('capture uses the visible ring radius at orb centers', () async {
    final engine = LumaWellEngine(
      store: _MemoryStore()
        ..save = _savedField([
          {'mass': 1.0, 'kind': 0, 'x': 0.42, 'y': 0.0, 'drift': 0.0},
          {'mass': 1.0, 'kind': 0, 'x': 0.66, 'y': 0.0, 'drift': 0.0},
        ]),
    );
    await engine.start();

    engine.beginCapture(0.42, 0);

    expect(engine.capturedIds, isEmpty);
    expect(engine.captureBlocked, isFalse);
  });

  test('spawning slows as the field becomes crowded', () async {
    final engine = LumaWellEngine(store: _MemoryStore(), random: Random(1));
    await engine.start();
    final normalInterval = engine.spawnInterval;
    for (var i = 0; i < 3000; i++) {
      engine.advance(0.04);
    }

    expect(engine.spawnInterval, greaterThan(normalInterval));
  });

  test('thin field removes a quarter of floating orbs', () async {
    final engine = LumaWellEngine(store: _MemoryStore(), random: Random(1));
    engine.setUnlimitedPowersResolver(() => true);
    await engine.start();
    final before = engine.orbs.length;

    engine.usePower(LumaWellPower.thinField);

    expect(engine.orbs.length, before - (before * 0.25).ceil());
  });

  test('planet visual radius is capped for endless play', () async {
    final engine = LumaWellEngine(
      store: _MemoryStore()
        ..save = {
          'score': 0,
          'merges': 0,
          'stage': 20,
          'charges': 1,
          'planetMass': 100000.0,
          'expandedCaptures': 0,
          'focusedCaptures': 0,
          'orbs': [
            {'mass': 1.0, 'kind': 0, 'x': 0.5, 'y': 0.0, 'drift': 0.0},
          ],
        },
    );
    await engine.start();

    expect(engine.planetRadius, 0.34);
  });

  test('restores a saved planet and its field', () async {
    final store = _MemoryStore()
      ..save = {
        'score': 41,
        'merges': 3,
        'stage': 2,
        'charges': 1,
        'planetMass': 35.0,
        'expandedCaptures': 2,
        'focusedCaptures': 0,
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

  test('chained merges build a combo that multiplies score', () async {
    final engine = LumaWellEngine(
      store: _MemoryStore()
        ..save = _savedField([
          {'mass': 1.0, 'kind': 0, 'x': 0.42, 'y': 0.0, 'drift': 0.0},
          {'mass': 1.0, 'kind': 0, 'x': 0.44, 'y': 0.0, 'drift': 0.0},
          {'mass': 1.0, 'kind': 0, 'x': -0.42, 'y': 0.0, 'drift': 0.0},
          {'mass': 1.0, 'kind': 0, 'x': -0.44, 'y': 0.0, 'drift': 0.0},
        ]),
      random: Random(1),
    );
    await engine.start();
    engine.beginCapture(0.42, 0);
    while (engine.merges < 1) {
      engine.advance(0.04);
    }
    final firstPoints = engine.mergePoints;
    expect(engine.combo, 1);

    engine.moveCapture(-0.42, 0);
    while (engine.merges < 2) {
      engine.advance(0.04);
    }

    expect(engine.combo, 2);
    expect(engine.bestCombo, 2);
    expect(engine.mergePoints, greaterThan(firstPoints));
  });

  test('combo expires after the window', () async {
    final engine = LumaWellEngine(
      store: _MemoryStore()
        ..save = _savedField([
          {'mass': 1.0, 'kind': 0, 'x': 0.42, 'y': 0.0, 'drift': 0.0},
          {'mass': 1.0, 'kind': 0, 'x': 0.44, 'y': 0.0, 'drift': 0.0},
          {'mass': 1.0, 'kind': 0, 'x': -0.42, 'y': 0.0, 'drift': 0.0},
          {'mass': 1.0, 'kind': 0, 'x': -0.44, 'y': 0.0, 'drift': 0.0},
        ]),
      random: Random(1),
    );
    await engine.start();
    engine.beginCapture(0.42, 0);
    while (engine.merges < 1) {
      engine.advance(0.04);
    }
    expect(engine.combo, 1);
    engine.endCapture();

    for (var i = 0; i < 160; i++) {
      engine.advance(0.04);
    }
    expect(engine.combo, 0);

    engine.beginCapture(-0.42, 0);
    while (engine.merges < 2) {
      engine.advance(0.04);
    }
    expect(engine.combo, 1);
  });

  test('volatile orbs drain payout and break the combo', () async {
    final engine = LumaWellEngine(
      store: _MemoryStore()
        ..save = _savedField([
          {'mass': 1.0, 'kind': 0, 'x': 0.42, 'y': 0.0, 'drift': 0.0},
          {'mass': 1.0, 'kind': 0, 'x': 0.44, 'y': 0.0, 'drift': 0.0},
          {
            'mass': 1.0,
            'kind': 0,
            'volatile': true,
            'x': 0.46,
            'y': 0.0,
            'drift': 0.0,
          },
        ]),
      random: Random(1),
    );
    await engine.start();
    engine.beginCapture(0.42, 0);
    while (engine.merges < 1) {
      engine.advance(0.04);
    }

    expect(engine.lastMergeHadVolatile, isTrue);
    expect(engine.combo, 0);
    expect(engine.mergePoints, 41);
    expect(engine.mergePoints, lessThan(54));
  });

  test('drift speeds up with stage', () async {
    final first = LumaWellEngine(store: _MemoryStore());
    await first.start();
    final fifth = LumaWellEngine(
      store: _MemoryStore()
        ..save = {
          'score': 0,
          'merges': 0,
          'stage': 5,
          'charges': 1,
          'planetMass': 116.0,
          'expandedCaptures': 0,
          'focusedCaptures': 0,
          'orbs': [
            {'mass': 1.0, 'kind': 5, 'x': 0.5, 'y': 0.0, 'drift': 0.0},
          ],
        },
    );
    await fifth.start();

    expect(fifth.driftFactor, greaterThan(first.driftFactor));
    expect(fifth.driftFactor, lessThanOrEqualTo(2.0));
  });

  test('capture attempts feed accuracy', () async {
    final engine = LumaWellEngine(
      store: _MemoryStore()
        ..save = _savedField([
          {'mass': 1.0, 'kind': 0, 'x': 0.42, 'y': 0.0, 'drift': 0.0},
          {'mass': 1.0, 'kind': 0, 'x': 0.44, 'y': 0.0, 'drift': 0.0},
        ]),
      random: Random(1),
    );
    await engine.start();
    engine.beginCapture(0.42, 0);
    while (engine.merges < 1) {
      engine.advance(0.04);
    }
    engine.endCapture();
    engine.beginCapture(-0.9, -0.9);
    engine.endCapture();

    expect(engine.attempts, 2);
    expect(engine.accuracy, 0.5);
  });

  test('save roundtrip preserves volatile, best combo, and attempts', () async {
    final store = _MemoryStore()
      ..save = {
        'score': 10,
        'merges': 2,
        'stage': 1,
        'charges': 1,
        'planetMass': 8.0,
        'expandedCaptures': 0,
        'focusedCaptures': 0,
        'bestCombo': 3,
        'attempts': 5,
        'orbs': [
          {
            'mass': 1.0,
            'kind': 0,
            'volatile': true,
            'x': 0.5,
            'y': 0.0,
            'drift': 0.0,
          },
        ],
      };
    final engine = LumaWellEngine(store: store);
    await engine.start();

    expect(engine.orbs.single.isVolatile, isTrue);
    expect(engine.bestCombo, 3);
    expect(engine.attempts, 5);
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
  'expandedCaptures': 0,
  'focusedCaptures': 0,
  'orbs': orbs,
};

Future<LumaWellEngine> _capturePair(int kind) async {
  final engine = LumaWellEngine(
    store: _MemoryStore()
      ..save = _savedField([
        {'mass': 1.0, 'kind': kind, 'x': 0.42, 'y': 0.0, 'drift': 0.0},
        {'mass': 1.0, 'kind': kind, 'x': 0.44, 'y': 0.0, 'drift': 0.0},
      ]),
  );
  await engine.start();
  engine.beginCapture(0.42, 0);
  for (var i = 0; i < 42; i++) {
    engine.advance(0.04);
  }
  return engine;
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
