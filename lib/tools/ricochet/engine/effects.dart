import 'dart:ui' show Color;

/// A short-lived debris spark. Gravity-affected, so a burst arcs rather than
/// expanding evenly.
class Particle {
  double x;
  double y;
  double vx;
  double vy;
  double life;
  final double maxLife;
  final Color color;
  final double size;

  Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.life,
    required this.maxLife,
    required this.color,
    required this.size,
  });

  double get alpha => (life / maxLife).clamp(0.0, 1.0);
}

/// A score popup or status toast, drifting upward as it fades.
class FloatingText {
  double x;
  double y;
  final String text;
  final Color color;
  double life;
  final double maxLife;
  final double size;

  FloatingText({
    required this.x,
    required this.y,
    required this.text,
    required this.color,
    required this.life,
    required this.maxLife,
    required this.size,
  });

  double get alpha => (life / maxLife).clamp(0.0, 1.0);
}

/// The expanding shockwave of an explosion.
class Ring {
  double x;
  double y;
  double radius;
  final double maxRadius;
  double life;

  Ring({
    required this.x,
    required this.y,
    required this.radius,
    required this.maxRadius,
    this.life = 1,
  });
}
