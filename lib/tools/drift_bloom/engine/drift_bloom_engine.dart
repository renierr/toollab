import 'dart:math' as math;

import 'package:flutter/foundation.dart';

class WindRing {
  final int id;
  final double x;
  final double y;
  final double radius;
  double age;
  final double life;
  final bool golden;
  bool grazed;

  WindRing({
    required this.id,
    required this.x,
    required this.y,
    required this.radius,
    this.age = 0,
    this.life = 10,
    this.golden = false,
    this.grazed = false,
  });
}

class BloomParticle {
  double x;
  double y;
  double vx;
  double vy;
  double age;
  final double life;

  BloomParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    this.age = 0,
    this.life = 0.9,
  });
}

class DriftBloomEngine extends ChangeNotifier {
  final math.Random _random;
  final List<WindRing> _rings = [];

  int _nextId = 1;
  double seedX = 0;
  double seedY = 0;
  double _velX = 0;
  double _velY = 0;
  double? _targetX;
  double? _targetY;
  double _time = 0;
  double _spawnFor = 0;
  int _score = 0;
  int _best = 0;
  int _petals = 0;
  int _combo = 0;
  double _comboFor = 0;
  int _bloomToken = 0;
  double _bloomX = 0;
  double _bloomY = 0;
  int _bloomPoints = 0;
  bool _lastBloomGolden = false;
  final List<math.Point<double>> _trail = [];
  final List<BloomParticle> _particles = [];

  bool Function() _usesEasyMode = () => false;
  double Function() _ringLife = () => 10;

  ValueChanged<int>? onBest;

  DriftBloomEngine({math.Random? random}) : _random = random ?? math.Random();

  List<WindRing> get rings => List.unmodifiable(_rings);
  int get score => _score;
  int get best => _best;
  int get petals => _petals;
  int get combo => _combo;
  int get bloomToken => _bloomToken;
  double get bloomX => _bloomX;
  double get bloomY => _bloomY;
  int get bloomPoints => _bloomPoints;
  bool get lastBloomGolden => _lastBloomGolden;
  double get nightFactor => (_petals / 12).clamp(0.0, 1.0);
  double get time => _time;
  List<math.Point<double>> get trail => List.unmodifiable(_trail);
  List<BloomParticle> get particles => List.unmodifiable(_particles);

  void setEasyModeResolver(bool Function() resolver) =>
      _usesEasyMode = resolver;
  void setRingLifeResolver(double Function() resolver) => _ringLife = resolver;

  static const double comboWindow = 5;

  void setBest(int value) {
    _best = value;
  }

  void newGame() {
    _rings.clear();
    _trail.clear();
    _particles.clear();
    seedX = 0;
    seedY = 0;
    _velX = 0;
    _velY = 0;
    _targetX = null;
    _targetY = null;
    _score = 0;
    _petals = 0;
    _combo = 0;
    _comboFor = 0;
    _spawnFor = 0;
    notifyListeners();
  }

  void steer(double? x, double? y) {
    _targetX = x;
    _targetY = y;
  }

  void advance(double seconds) {
    if (seconds <= 0) return;
    final dt = seconds.clamp(0.0, 0.04);
    _time += dt;
    final easy = _usesEasyMode();
    final breeze = easy ? 0.05 : 0.10;
    if (_comboFor > 0) {
      _comboFor = math.max(0, _comboFor - dt);
      if (_comboFor == 0) _combo = 0;
    }
    if (_targetX != null && _targetY != null) {
      _velX += (_targetX! - seedX) * 3 * dt;
      _velY += (_targetY! - seedY) * 3 * dt;
    } else {
      _velX += breeze * dt;
      _velY += 0.06 * math.sin(_time * 0.5) * dt;
    }
    final damp = math.max(0, 1 - 1.2 * dt);
    _velX *= damp;
    _velY *= damp;
    final speed = math.sqrt(_velX * _velX + _velY * _velY);
    if (speed > 1.2) {
      _velX *= 1.2 / speed;
      _velY *= 1.2 / speed;
    }
    seedX = (seedX + _velX * dt).clamp(-1.0, 1.0);
    seedY = (seedY + _velY * dt).clamp(-1.0, 1.0);
    _trail.add(math.Point(seedX, seedY));
    while (_trail.length > 14) {
      _trail.removeAt(0);
    }
    for (var i = _particles.length - 1; i >= 0; i--) {
      final particle = _particles[i];
      particle.age += dt;
      if (particle.age >= particle.life) {
        _particles.removeAt(i);
        continue;
      }
      particle.x += particle.vx * dt;
      particle.y += particle.vy * dt;
    }
    final spawnInterval = easy ? 2.6 : 2.0;
    final maxRings = easy ? 4 : 5;
    _spawnFor += dt;
    if (_spawnFor >= spawnInterval && _rings.length < maxRings) {
      _spawnFor = 0;
      _spawnRing();
    }
    for (var i = _rings.length - 1; i >= 0; i--) {
      final ring = _rings[i];
      ring.age += dt;
      if (ring.age >= ring.life) {
        if (!ring.grazed) {
          _combo = 0;
          _comboFor = 0;
        }
        _rings.removeAt(i);
        continue;
      }
      final dx = seedX - ring.x;
      final dy = seedY - ring.y;
      final dist = math.sqrt(dx * dx + dy * dy);
      if (dist <= ring.radius * 0.4) {
        _bloom(ring);
        _rings.removeAt(i);
      } else if (!ring.grazed && dist <= ring.radius) {
        ring.grazed = true;
        _comboFor = comboWindow;
        if (_combo == 0) _combo = 1;
        _addScore(2);
      }
    }
    notifyListeners();
  }

  void _bloom(WindRing ring) {
    _combo = _comboFor > 0 ? _combo + 1 : 1;
    _comboFor = comboWindow;
    _petals++;
    final points = (ring.golden ? 20 : 10) * (_combo < 5 ? _combo : 5);
    _addScore(points);
    _bloomX = ring.x;
    _bloomY = ring.y;
    _bloomPoints = points;
    _lastBloomGolden = ring.golden;
    _bloomToken++;
    for (var i = 0; i < (ring.golden ? 16 : 10); i++) {
      final angle = (i / 10) * math.pi * 2 + _random.nextDouble() * 0.5;
      final speed = 0.25 + _random.nextDouble() * 0.35;
      _particles.add(
        BloomParticle(
          x: ring.x,
          y: ring.y,
          vx: math.cos(angle) * speed,
          vy: math.sin(angle) * speed,
        ),
      );
    }
  }

  void _addScore(int points) {
    _score += points;
    if (_score > _best) {
      _best = _score;
      onBest?.call(_best);
    }
  }

  void _spawnRing() {
    _rings.add(
      WindRing(
        id: _nextId++,
        x: (_random.nextDouble() - 0.5) * 1.7,
        y: (_random.nextDouble() - 0.5) * 1.7,
        radius: 0.16 + _random.nextDouble() * 0.08,
        life: _ringLife(),
        golden: _random.nextDouble() < 1 / 6,
      ),
    );
  }
}
