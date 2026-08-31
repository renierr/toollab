import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'luma_well_store.dart';

class LumaOrb {
  final int id;
  final double mass;
  final int kind;
  double x;
  double y;
  double drift;

  LumaOrb({
    required this.id,
    required this.mass,
    required this.kind,
    required this.x,
    required this.y,
    required this.drift,
  });
}

enum LumaWellPower { pulse, stabilize, brightenNext }

class LumaWellEngine extends ChangeNotifier {
  final LumaWellStore _store;
  final math.Random _random;
  final List<LumaOrb> _orbs = [];
  final Set<int> _capturedIds = {};

  bool Function() _usesEasyMode = () => false;
  int _nextId = 1;
  int _score = 0;
  int _best = 0;
  int _merges = 0;
  int _stage = 1;
  int _powerCharges = 1;
  double _planetMass = 4;
  double _spawnFor = 0;
  double _stabilizedFor = 0;
  double _captureX = 0;
  double _captureY = 0;
  double _captureFor = 0;

  LumaWellEngine({LumaWellStore? store, math.Random? random})
    : _store = store ?? const LumaWellStore(),
      _random = random ?? math.Random();

  List<LumaOrb> get orbs => List.unmodifiable(_orbs);
  Set<int> get capturedIds => Set.unmodifiable(_capturedIds);
  int get score => _score;
  int get best => _best;
  int get merges => _merges;
  int get stage => _stage;
  int get powerCharges => _powerCharges;
  double get planetRadius => 0.07 + math.sqrt(_planetMass) * 0.013;
  bool get isGameOver => false;
  bool get isCapturing => _captureFor > 0;
  double get captureX => _captureX;
  double get captureY => _captureY;
  double get captureProgress => (_captureFor / 2.5).clamp(0, 1);

  double radiusFor(LumaOrb orb) => 0.024 + math.sqrt(orb.mass) * 0.016;

  double get _nextStageMass => 4 + _stage * 28;

  void setEasyModeResolver(bool Function() resolver) =>
      _usesEasyMode = resolver;

  Future<void> start() async {
    _best = await _store.loadBest();
    _deal();
    notifyListeners();
  }

  void newGame() {
    _deal();
    notifyListeners();
  }

  void beginCapture(double x, double y) {
    _captureX = x;
    _captureY = y;
    _captureFor = 0.001;
    _updateCaptured();
    notifyListeners();
  }

  void moveCapture(double x, double y) {
    if (!isCapturing) return;
    _captureX = x;
    _captureY = y;
    _captureFor = 0.001;
    _updateCaptured();
    notifyListeners();
  }

  void endCapture() {
    _captureFor = 0;
    _capturedIds.clear();
    notifyListeners();
  }

  void advance(double seconds) {
    if (seconds <= 0) return;
    final dt = seconds.clamp(0.0, 0.04);
    _stabilizedFor = math.max(0, _stabilizedFor - dt);
    for (final orb in _orbs) {
      final speed = _stabilizedFor > 0 ? 0.1 : orb.drift;
      final angle = math.atan2(orb.y, orb.x) + speed * dt;
      final distance = math.sqrt(orb.x * orb.x + orb.y * orb.y);
      orb.x = math.cos(angle) * distance;
      orb.y = math.sin(angle) * distance;
    }
    _spawnFor += dt;
    final spawnEvery = math.max(
      _usesEasyMode() ? 1.5 : 1.05,
      2.1 - _stage * 0.16,
    );
    if (_spawnFor >= spawnEvery) {
      _spawnFor = 0;
      _spawn();
    }
    if (isCapturing) {
      _updateCaptured();
      if (_capturedIds.length >= 2) {
        _captureFor += dt;
        if (_captureFor >= 2.5) _completeCapture();
      } else {
        _captureFor = 0.001;
      }
    }
    notifyListeners();
  }

  void usePower(LumaWellPower power) {
    if (_powerCharges == 0) return;
    _powerCharges--;
    switch (power) {
      case LumaWellPower.pulse:
        for (final orb in _orbs) {
          orb.x *= 1.18;
          orb.y *= 1.18;
        }
      case LumaWellPower.stabilize:
        _stabilizedFor = 7;
      case LumaWellPower.brightenNext:
        final nearby = _orbs
            .where(
              (orb) =>
                  math.sqrt(orb.x * orb.x + orb.y * orb.y) <
                  planetRadius + 0.27,
            )
            .take(8)
            .toList();
        _absorb(nearby);
    }
    notifyListeners();
  }

  void _updateCaptured() {
    final candidates = _orbs.where((orb) {
      final dx = orb.x - _captureX;
      final dy = orb.y - _captureY;
      return math.sqrt(dx * dx + dy * dy) < 0.23;
    }).toList();
    if (candidates.isEmpty) {
      _capturedIds.clear();
      return;
    }
    final kind = candidates
        .fold<LumaOrb>(
          candidates.first,
          (closest, orb) =>
              (orb.x - _captureX) * (orb.x - _captureX) +
                      (orb.y - _captureY) * (orb.y - _captureY) <
                  (closest.x - _captureX) * (closest.x - _captureX) +
                      (closest.y - _captureY) * (closest.y - _captureY)
              ? orb
              : closest,
        )
        .kind;
    _capturedIds
      ..clear()
      ..addAll(
        candidates.where((orb) => orb.kind == kind).map((orb) => orb.id),
      );
  }

  void _completeCapture() {
    final captured = _orbs
        .where((orb) => _capturedIds.contains(orb.id))
        .toList();
    if (captured.length < 2) return;
    _merges++;
    _absorb(captured, multiplier: captured.length);
    _captureFor = 0;
    _capturedIds.clear();
  }

  void _absorb(List<LumaOrb> orbs, {int multiplier = 1}) {
    if (orbs.isEmpty) return;
    final mass = orbs.fold<double>(0, (total, orb) => total + orb.mass);
    _orbs.removeWhere(orbs.contains);
    _planetMass += mass;
    _score += mass.round() * multiplier;
    if (_score > _best) {
      _best = _score;
      _store.saveBest(_best);
    }
    while (_planetMass >= _nextStageMass) {
      _stage++;
      _powerCharges++;
    }
  }

  void _deal() {
    _orbs.clear();
    _capturedIds.clear();
    _nextId = 1;
    _score = 0;
    _merges = 0;
    _stage = 1;
    _powerCharges = 1;
    _planetMass = 4;
    _captureFor = 0;
    _spawnFor = 0;
    final count = _usesEasyMode() ? 14 : 18;
    for (var i = 0; i < count; i++) {
      _spawn();
    }
  }

  void _spawn() {
    final angle = _random.nextDouble() * math.pi * 2;
    final distance = 0.42 + _random.nextDouble() * 0.8;
    _orbs.add(
      LumaOrb(
        id: _nextId++,
        mass: (1 + _random.nextInt(3)).toDouble(),
        kind: _random.nextInt(math.min(_stage, 4)),
        x: math.cos(angle) * distance,
        y: math.sin(angle) * distance,
        drift: (_random.nextDouble() - 0.5) * 0.16,
      ),
    );
  }
}
