import 'dart:ui' show Offset;

/// One ball in flight.
///
/// [pierce] and [bomb] are inherited from the charges banked before the volley
/// fired and stay with the ball for its whole flight; a ball can be both.
class Ball {
  double x;
  double y;
  double vx;
  double vy;
  final bool pierce;
  final bool bomb;

  /// Bricks a piercing ball has already damaged, so drilling through a tile
  /// costs it exactly one HP however long the ball overlaps it.
  final Set<int> hit = {};

  /// Cooldown before this ball's next bomb detonation.
  double cd;

  /// Cooldown before this ball may bounce off another ramp or orb. Without it a
  /// ball can ping-pong forever inside a cluster of round or angled tiles.
  double shapeCd;

  static const int trailCapacity = 9;
  final List<Offset> _trail = List<Offset>.filled(trailCapacity, Offset.zero);
  int _trailStart = 0;
  int trailLength = 0;

  Ball({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    this.pierce = false,
    this.bomb = false,
    this.cd = 0,
    this.shapeCd = 0,
  });

  Offset trailAt(int index) => _trail[(_trailStart + index) % trailCapacity];

  void addTrail(Offset point) {
    if (trailLength < trailCapacity) {
      _trail[(_trailStart + trailLength) % trailCapacity] = point;
      trailLength++;
      return;
    }
    _trail[_trailStart] = point;
    _trailStart = (_trailStart + 1) % trailCapacity;
  }
}
