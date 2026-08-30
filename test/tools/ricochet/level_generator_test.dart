import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/tools/ricochet/engine/geometry.dart';
import 'package:tool_lab/tools/ricochet/engine/level_generator.dart';
import 'package:tool_lab/tools/ricochet/engine/tile.dart';

LevelGenerator _generator(int seed) {
  var uid = 0;
  return LevelGenerator(() => uid++, random: math.Random(seed));
}

void main() {
  test('generated levels stay playable within their durability budget', () {
    for (var level = 1; level <= 100; level++) {
      for (var seed = 0; seed < 20; seed++) {
        final layout = _generator(seed).generate(level, ballCount: 1);
        final totalHp = layout.bricks.fold<int>(
          0,
          (total, brick) => total + brick.maxHp,
        );

        expect(layout.bricks, isNotEmpty);
        expect(
          totalHp,
          lessThanOrEqualTo(
            _generator(seed).durabilityBudget(
              level,
              layout.bricks.length + layout.pickups.length,
              1,
            ),
          ),
        );
        expect(layout.pickups.length, greaterThanOrEqualTo(2));
        for (final brick in layout.bricks) {
          expect(brick.x, greaterThanOrEqualTo(0));
          expect(brick.x + brick.width, lessThanOrEqualTo(Board.width));
          expect(
            brick.y + brick.height,
            lessThanOrEqualTo(Board.dangerY - 3 * Board.cell),
          );
          expect(brick.maxHp, greaterThanOrEqualTo(1));
        }
      }
    }
  });

  test('advanced tile mechanics remain locked at level one', () {
    for (var seed = 0; seed < 100; seed++) {
      final layout = _generator(seed).generate(1, ballCount: 1);
      expect(
        layout.bricks.any(
          (brick) =>
              brick.type == TileType.blast ||
              brick.type == TileType.pierce ||
              brick.type == TileType.split ||
              brick.type == TileType.orb ||
              brick.type.isRamp,
        ),
        isFalse,
      );
    }
  });

  test('split tiles unlock at level seven and stay capped', () {
    for (var seed = 0; seed < 100; seed++) {
      final layout = _generator(seed).generate(100, ballCount: 1);
      expect(
        layout.bricks.where((brick) => brick.type == TileType.split).length,
        lessThanOrEqualTo(2),
      );
    }
  });

  test('large volleys receive a proportional durability budget', () {
    final generator = _generator(0);

    expect(
      generator.durabilityBudget(30, 50, 100),
      greaterThan(generator.durabilityBudget(30, 50, 1)),
    );
    expect(generator.durabilityBudget(30, 50, 100), 2200);
  });
}
