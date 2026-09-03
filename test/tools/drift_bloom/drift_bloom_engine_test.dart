import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/tools/drift_bloom/engine/drift_bloom_engine.dart';

void main() {
  test('passing a ring center blooms a petal', () {
    final engine = DriftBloomEngine(random: Random(1));
    for (var i = 0; i < 60; i++) {
      engine.advance(0.04);
    }
    expect(engine.rings, isNotEmpty);
    final ring = engine.rings.first;
    engine.steer(ring.x, ring.y);
    for (var i = 0; i < 200 && engine.petals < 1; i++) {
      engine.advance(0.04);
    }

    expect(engine.petals, 1);
    expect(engine.score, greaterThan(0));
  });

  test('grazing a ring scores without blooming', () {
    final engine = DriftBloomEngine(random: Random(1));
    for (var i = 0; i < 60; i++) {
      engine.advance(0.04);
    }
    final ring = engine.rings.first;
    final dist = (ring.x * ring.x + ring.y * ring.y);
    final inv = dist > 0.01 ? 1 / sqrt(dist) : 1.0;
    final px = -ring.y * inv;
    final py = ring.x * inv;
    engine.steer(
      ring.x + px * ring.radius * 0.7,
      ring.y + py * ring.radius * 0.7,
    );
    for (var i = 0; i < 200 && engine.score < 1; i++) {
      engine.advance(0.04);
    }

    expect(engine.score, greaterThan(0));
    expect(engine.petals, 0);
  });

  test('new game clears the field', () {
    final engine = DriftBloomEngine(random: Random(1));
    for (var i = 0; i < 60; i++) {
      engine.advance(0.04);
    }
    engine.steer(0.5, 0.5);
    engine.advance(0.04);
    engine.newGame();

    expect(engine.score, 0);
    expect(engine.petals, 0);
    expect(engine.rings, isEmpty);
    expect(engine.seedX, 0);
  });

  test('blooms leave particles and the seed leaves a trail', () {
    final engine = DriftBloomEngine(random: Random(1));
    for (var i = 0; i < 60; i++) {
      engine.advance(0.04);
    }
    expect(engine.trail, isNotEmpty);
    final ring = engine.rings.first;
    engine.steer(ring.x, ring.y);
    for (var i = 0; i < 200 && engine.petals < 1; i++) {
      engine.advance(0.04);
    }

    expect(engine.particles, isNotEmpty);
  });

  test('ring lifetime follows the settings resolver', () {
    final engine = DriftBloomEngine(random: Random(1));
    engine.setRingLifeResolver(() => 8);
    for (var i = 0; i < 60; i++) {
      engine.advance(0.04);
    }

    expect(engine.rings, isNotEmpty);
    expect(engine.rings.first.life, 8);
  });

  test('golden rings bloom double points', () {
    final engine = DriftBloomEngine(random: Random(1));
    WindRing? golden;
    for (var i = 0; i < 3000 && golden == null; i++) {
      engine.advance(0.04);
      for (final ring in engine.rings) {
        if (ring.golden) golden = ring;
      }
    }
    expect(golden, isNotNull);
    engine.steer(golden!.x, golden.y);
    for (var i = 0; i < 600 && !engine.lastBloomGolden; i++) {
      engine.advance(0.04);
    }

    expect(engine.lastBloomGolden, isTrue);
    expect(engine.bloomPoints, engine.combo * 20);
  });

  test('night falls as petals grow', () {
    final engine = DriftBloomEngine(random: Random(1));
    expect(engine.nightFactor, 0);
    for (var i = 0; i < 60; i++) {
      engine.advance(0.04);
    }
    final ring = engine.rings.first;
    engine.steer(ring.x, ring.y);
    for (var i = 0; i < 200 && engine.petals < 1; i++) {
      engine.advance(0.04);
    }

    expect(engine.nightFactor, closeTo(1 / 12, 0.001));
  });
}
