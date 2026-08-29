import 'dart:math' as math;

import 'geometry.dart';
import 'stencils.dart';
import 'tile.dart';

/// The bricks and pickups a freshly generated level starts with.
class LevelLayout {
  final List<Brick> bricks;
  final List<Pickup> pickups;

  const LevelLayout({required this.bricks, required this.pickups});
}

/// Cuts a board out of the hand-drawn [stencils].
///
/// Special tiles arrive from three independent sources so no kind is hostage to
/// which stencil got drawn: the hand-placed stencil art, a per-tile roll on
/// every plain `#`, and a rare-seeding pass that converts a handful of plain
/// tiles ([rareMix]). Without the seeding pass, ramps and orbs would each live
/// in exactly one layout.
class LevelGenerator {
  final math.Random _random;
  final int Function() _nextUid;

  LevelGenerator(this._nextUid, {math.Random? random})
    : _random = random ?? math.Random();

  /// Inclusive on both ends, like the browser original's `randInt`.
  int _randInt(int lo, int hi) => lo + _random.nextInt(hi - lo + 1);

  LevelLayout generate(int level) {
    final bricks = <Brick>[];
    final pickups = <Pickup>[];

    final lo = math.max(1, (level * 0.8).round());
    final hi = math.max(lo + 2, (level * 1.7).round());
    final bombChance = math.min(0.02 + level * 0.0005, 0.04);

    // Rows that fit between the top edge and the ~3-row clear zone above the
    // danger line, so a layout never spawns inside the launch area.
    final maxRows = ((Board.dangerY - 3 * Board.cell - Board.cell) / Board.cell)
        .floor();

    final arts = <int>[_randInt(0, stencils.length - 1)];
    var used = stencils[arts[0]].length;
    // From level 8, two stencils usually stack into one bigger composition —
    // but only when the taller result still clears the launch area.
    if (level >= 8 && _random.nextDouble() < 0.65) {
      final second = _randInt(0, stencils.length - 1);
      if (second != arts[0] && used + 1 + stencils[second].length <= maxRows) {
        arts.add(second);
        used += 1 + stencils[second].length;
      }
    }

    // A tall composition may start up to 4 rows above the top edge and slide
    // into view one row per turn; at least one row is always visible.
    final minOy = -math.min(4, used - 1);
    final maxOy = math.max(minOy, maxRows - used);
    var oy = _randInt(minOy, maxOy);

    for (final artIndex in arts) {
      final rows = stencils[artIndex];
      final artWidth = rows[0].length;
      final ox = ((Board.columns - artWidth) / 2).floor();
      final mirror = _random.nextDouble() < 0.5;

      for (var r = 0; r < rows.length; r++) {
        final line = rows[r];
        for (var i = 0; i < artWidth; i++) {
          final ch = mirror ? line[artWidth - 1 - i] : line[i];
          if (ch == '.') continue;

          final TileType type;
          if (ch == '#') {
            final roll = _random.nextDouble();
            if (roll < bombChance) {
              type = TileType.bomb;
            } else if (roll < bombChance + 0.03) {
              type = TileType.gift;
            } else if (roll < bombChance + 0.07) {
              type = TileType.mult;
            } else {
              type = TileType.normal;
            }
          } else {
            type = stencilChars[ch] ?? TileType.normal;
          }

          var hp = _randInt(lo, hi);
          if (_random.nextDouble() < 0.12) hp = (hp * 1.5).round();
          bricks.add(
            Brick(
              uid: _nextUid(),
              x: (ox + i) * Board.cell,
              y: (oy + r) * Board.cell,
              hp: hp,
              maxHp: hp,
              type: type,
            ),
          );
        }
      }
      oy += rows.length + 1;
    }

    _seedRares(bricks, level);
    _placePickups(bricks, pickups);
    return LevelLayout(bricks: bricks, pickups: pickups);
  }

  void _seedRares(List<Brick> bricks, int level) {
    for (final seed in rareMix) {
      if (level < seed.from || _random.nextDouble() >= seed.chance) continue;
      final isRampSeed = seed.type.isRamp;
      final existing = bricks
          .where((b) => isRampSeed ? b.type.isRamp : b.type == seed.type)
          .length;
      if (existing >= seed.cap) continue;

      final pool = bricks.where((b) => b.type == TileType.normal).toList();
      var remaining = _randInt(seed.lo, seed.hi);
      while (remaining-- > 0 && pool.isNotEmpty) {
        final brick = pool.removeAt(_randInt(0, pool.length - 1));
        brick.type = isRampSeed
            ? (_random.nextDouble() < 0.5 ? TileType.rampA : TileType.rampB)
            : seed.type;
      }
    }
  }

  /// Swaps 1–3 plain tiles for green (+) pickups. They replace a brick rather
  /// than sitting on top of one, so the board's tile count stays honest.
  void _placePickups(List<Brick> bricks, List<Pickup> pickups) {
    final pool = bricks.where((b) => b.type == TileType.normal).toList();
    var remaining = _randInt(1, 3);
    while (remaining-- > 0 && pool.isNotEmpty) {
      final brick = pool.removeAt(_randInt(0, pool.length - 1));
      if (!bricks.remove(brick)) continue;
      pickups.add(
        Pickup(
          x: brick.centerX,
          y: brick.centerY,
          seed: _random.nextDouble() * 6,
        ),
      );
    }
  }
}
