import 'geometry.dart';

/// What a tile does *in addition* to being a breakable brick. Except
/// [TileType.normal] every kind still carries HP and shatters for points; the
/// kind only decides the extra effect and the shape it collides as.
enum TileType {
  normal,
  bomb,
  gift,
  mult,
  pierce,
  blast,
  rampA,
  rampB,
  orb;

  /// Ramps are the two halves of one mechanic — `rampA` is the `/` slope,
  /// `rampB` the `\` — and the generator caps and seeds them as a single kind.
  bool get isRamp => this == TileType.rampA || this == TileType.rampB;

  /// The `/` variant: its solid half is the lower right of the cell.
  bool get isRampA => this == TileType.rampA;

  static TileType? fromId(String? id) {
    if (id == null) return null;
    for (final type in TileType.values) {
      if (type.name == id) return type;
    }
    return null;
  }
}

/// One tile on the board. Mutable and updated in place — the simulation touches
/// every brick many times per frame, so allocating replacements would dominate
/// the frame budget during a fast volley.
class Brick {
  final int uid;
  double x;
  double y;
  int hp;
  final int maxHp;
  TileType type;

  /// White impact flash, 1 at the moment of the hit and decaying to 0.
  double flash;

  /// Set the moment the brick leaves the board, so an explosion iterating a
  /// snapshot of the brick list cannot damage it twice.
  bool dead;

  Brick({
    required this.uid,
    required this.x,
    required this.y,
    required this.hp,
    required this.maxHp,
    this.type = TileType.normal,
    this.flash = 1,
    this.dead = false,
  });

  double get width => Board.cell;
  double get height => Board.cell;
  double get centerX => x + Board.cell / 2;
  double get centerY => y + Board.cell / 2;
}

/// The green (+) pickup. Not a brick: no HP, cannot be shot away, collected on
/// touch for a permanent extra ball.
class Pickup {
  double x;
  double y;
  final double radius;

  /// Phase offset so a board full of pickups does not pulse in lockstep.
  final double seed;

  Pickup({required this.x, required this.y, this.radius = 14, this.seed = 0});
}
