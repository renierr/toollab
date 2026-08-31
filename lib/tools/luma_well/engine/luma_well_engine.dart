import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/foundation.dart';

import 'luma_well_store.dart';

class LumaOrb {
  final int id;
  final double mass;
  final int kind;
  final bool isPower;
  final LumaWellPower? power;
  double x;
  double y;
  double drift;

  LumaOrb({
    required this.id,
    required this.mass,
    required this.kind,
    this.isPower = false,
    this.power,
    required this.x,
    required this.y,
    required this.drift,
  });
}

enum LumaWellPower { pulse, stabilize, expandField, focusField, thinField }

enum LumaWellPowerOrbEffect { charge, expandField, focusField }

class LumaWellEngine extends ChangeNotifier {
  final LumaWellStore _store;
  final math.Random _random;
  final List<LumaOrb> _orbs = [];
  final Set<int> _capturedIds = {};

  bool Function() _usesEasyMode = () => false;
  bool Function() _usesUnlimitedPowers = () => false;
  double Function() _baseCaptureTime = () => 1.5;
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
  double _activeCaptureRadius = 0.23;
  double _activeCaptureTime = 1.5;
  double _persistFor = 0;
  int _expandedCaptures = 0;
  int _focusedCaptures = 0;
  bool _captureBlocked = false;
  int _mergeToken = 0;
  double _mergeX = 0;
  double _mergeY = 0;
  int _mergePoints = 0;
  int _powerCollectedToken = 0;
  LumaWellPowerOrbEffect? _lastPowerOrbEffect;

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
  double get planetRadius =>
      math.min(0.34, 0.07 + math.sqrt(_planetMass) * 0.013);
  bool get isGameOver => false;
  bool get isCapturing => _captureFor > 0;
  double get captureX => _captureX;
  double get captureY => _captureY;
  double get captureTime =>
      isCapturing ? _activeCaptureTime : _configuredCaptureTime;
  double get _configuredCaptureTime =>
      _baseCaptureTime() +
      (_expandedCaptures > 0
          ? 0.5
          : _focusedCaptures > 0
          ? -0.35
          : 0);
  double get captureProgress => (_captureFor / captureTime).clamp(0, 1);
  double get captureRadius =>
      isCapturing ? _activeCaptureRadius : _configuredCaptureRadius;
  double get _configuredCaptureRadius => _expandedCaptures > 0
      ? 0.31
      : _focusedCaptures > 0
      ? 0.17
      : 0.23;
  double get spawnInterval {
    final base = math.max(_usesEasyMode() ? 1.5 : 1.05, 2.1 - _stage * 0.16);
    final crowding = math.max(0, _orbs.length - 48) * 0.12;
    return math.min(3.0, base + crowding);
  }

  bool get captureBlocked => _captureBlocked;
  int get expandedCaptures => _expandedCaptures;
  int get focusedCaptures => _focusedCaptures;
  int get mergeToken => _mergeToken;
  double get mergeX => _mergeX;
  double get mergeY => _mergeY;
  int get mergePoints => _mergePoints;
  int get powerCollectedToken => _powerCollectedToken;
  LumaWellPowerOrbEffect? get lastPowerOrbEffect => _lastPowerOrbEffect;

  double radiusFor(LumaOrb orb) => 0.024 + math.sqrt(orb.mass) * 0.016;
  int get highestUnlockedNumber => math.min(6, _stage + 1);

  double get _nextStageMass => 4 + _stage * 28;

  void setEasyModeResolver(bool Function() resolver) =>
      _usesEasyMode = resolver;
  void setUnlimitedPowersResolver(bool Function() resolver) =>
      _usesUnlimitedPowers = resolver;
  void setCaptureTimeResolver(double Function() resolver) =>
      _baseCaptureTime = resolver;

  Future<void> start() async {
    _best = await _store.loadBest();
    final save = await _store.loadSave();
    if (save == null || !_hydrate(save)) {
      _deal();
    }
    notifyListeners();
  }

  void newGame() {
    _deal();
    unawaited(_store.clearSave());
    notifyListeners();
  }

  Future<void> saveNow() => _store.writeSave(_serialized());

  void beginCapture(double x, double y) {
    _captureX = x;
    _captureY = y;
    _activeCaptureRadius = _configuredCaptureRadius;
    _activeCaptureTime = _configuredCaptureTime;
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
    _captureBlocked = false;
    notifyListeners();
    _save();
  }

  void advance(double seconds) {
    if (seconds <= 0) return;
    final dt = seconds.clamp(0.0, 0.04);
    _stabilizedFor = math.max(0, _stabilizedFor - dt);
    for (final orb in _orbs) {
      if (isCapturing && _capturedIds.contains(orb.id)) {
        orb.x += (_captureX - orb.x) * dt * 2.2;
        orb.y += (_captureY - orb.y) * dt * 2.2;
        continue;
      }
      final speed = _stabilizedFor > 0 ? orb.drift * 0.15 : orb.drift;
      final angle = math.atan2(orb.y, orb.x) + speed * dt;
      final distance = math.sqrt(orb.x * orb.x + orb.y * orb.y);
      orb.x = math.cos(angle) * distance;
      orb.y = math.sin(angle) * distance;
    }
    _spawnFor += dt;
    if (_spawnFor >= spawnInterval) {
      _spawnFor = 0;
      _spawn();
    }
    if (isCapturing) {
      _updateCaptured();
      if (_capturedIds.length >= 2) {
        _captureFor += dt;
        if (_captureFor >= captureTime) _completeCapture();
      } else {
        _captureFor = 0.001;
      }
    }
    _persistFor += dt;
    if (_persistFor >= 2) {
      _persistFor = 0;
      _save();
    }
    notifyListeners();
  }

  void usePower(LumaWellPower power) {
    if (_powerCharges == 0 && !_usesUnlimitedPowers()) return;
    if (!_usesUnlimitedPowers()) _powerCharges--;
    switch (power) {
      case LumaWellPower.pulse:
        for (final orb in _orbs) {
          orb.x *= 1.18;
          orb.y *= 1.18;
        }
      case LumaWellPower.stabilize:
        _stabilizedFor = 7;
      case LumaWellPower.expandField:
        _expandedCaptures += 3;
        _focusedCaptures = 0;
      case LumaWellPower.focusField:
        _focusedCaptures += 3;
        _expandedCaptures = 0;
      case LumaWellPower.thinField:
        final removeCount = (_orbs.length * 0.25).ceil();
        _orbs.sort((a, b) {
          final distanceA = a.x * a.x + a.y * a.y;
          final distanceB = b.x * b.x + b.y * b.y;
          return distanceB.compareTo(distanceA);
        });
        _orbs.removeRange(0, math.min(removeCount, _orbs.length));
    }
    notifyListeners();
    _save();
  }

  void _updateCaptured() {
    final candidates = _orbs.where((orb) {
      final dx = orb.x - _captureX;
      final dy = orb.y - _captureY;
      return math.sqrt(dx * dx + dy * dy) <= _activeCaptureRadius;
    }).toList();
    if (candidates.isEmpty) {
      _capturedIds.clear();
      _captureBlocked = false;
      return;
    }
    final normal = candidates.where((orb) => !orb.isPower).toList();
    final powerCount = candidates.where((orb) => orb.isPower).length;
    if (normal.length + powerCount < 2 ||
        (powerCount > 0 && normal.length < 2)) {
      _captureBlocked = false;
      _capturedIds.clear();
      return;
    }
    final lowestKind = normal.fold<int>(
      normal.first.kind,
      (lowest, orb) => math.min(lowest, orb.kind),
    );
    final highestKind = normal.fold<int>(
      normal.first.kind,
      (highest, orb) => math.max(highest, orb.kind),
    );
    _captureBlocked = highestKind - lowestKind > 1;
    _capturedIds
      ..clear()
      ..addAll(
        _captureBlocked ? const <int>[] : candidates.map((orb) => orb.id),
      );
  }

  void _completeCapture() {
    final captured = _orbs
        .where((orb) => _capturedIds.contains(orb.id))
        .toList();
    if (!_isValidCapture(captured)) {
      _captureFor = 0.001;
      _capturedIds.clear();
      _captureBlocked = true;
      return;
    }
    for (final orb in captured.where((orb) => orb.isPower)) {
      switch (orb.power) {
        case LumaWellPower.expandField:
          _expandedCaptures += 3;
          _focusedCaptures = 0;
          _lastPowerOrbEffect = LumaWellPowerOrbEffect.expandField;
          _powerCollectedToken++;
        case LumaWellPower.focusField:
          _focusedCaptures += 3;
          _expandedCaptures = 0;
          _lastPowerOrbEffect = LumaWellPowerOrbEffect.focusField;
          _powerCollectedToken++;
        case null:
        case LumaWellPower.pulse:
        case LumaWellPower.stabilize:
        case LumaWellPower.thinField:
          _powerCharges++;
          _lastPowerOrbEffect = LumaWellPowerOrbEffect.charge;
          _powerCollectedToken++;
      }
    }
    _merges++;
    _absorb(captured, multiplier: captured.length);
    _captureFor = 0;
    _activeCaptureRadius = _configuredCaptureRadius;
    _activeCaptureTime = _configuredCaptureTime;
    _capturedIds.clear();
    _captureBlocked = false;
    if (_expandedCaptures > 0) _expandedCaptures--;
    if (_focusedCaptures > 0) _focusedCaptures--;
  }

  bool _isValidCapture(List<LumaOrb> orbs) {
    final normal = orbs.where((orb) => !orb.isPower).toList();
    if (normal.length + orbs.where((orb) => orb.isPower).length < 2) {
      return false;
    }
    if (orbs.any((orb) => orb.isPower) && normal.length < 2) {
      return false;
    }
    if (normal.isEmpty) return false;
    final lowest = normal.fold<int>(
      normal.first.kind,
      (value, orb) => math.min(value, orb.kind),
    );
    final highest = normal.fold<int>(
      normal.first.kind,
      (value, orb) => math.max(value, orb.kind),
    );
    return highest - lowest <= 1;
  }

  void _absorb(List<LumaOrb> orbs, {int multiplier = 1}) {
    if (orbs.isEmpty) return;
    final mass = orbs.fold<double>(
      0,
      (total, orb) => total + orb.mass * (orb.kind + 1),
    );
    _mergeX = orbs.fold<double>(0, (total, orb) => total + orb.x) / orbs.length;
    _mergeY = orbs.fold<double>(0, (total, orb) => total + orb.y) / orbs.length;
    _orbs.removeWhere(orbs.contains);
    _planetMass += mass;
    final groupBonus = orbs.length * orbs.length;
    _score += mass.round() * multiplier * groupBonus;
    _mergePoints = mass.round() * multiplier * groupBonus;
    _mergeToken++;
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
    _activeCaptureRadius = _configuredCaptureRadius;
    _activeCaptureTime = _configuredCaptureTime;
    _expandedCaptures = 0;
    _focusedCaptures = 0;
    _captureBlocked = false;
    _spawnFor = 0;
    _persistFor = 0;
    final count = _usesEasyMode() ? 14 : 18;
    for (var i = 0; i < count; i++) {
      _spawn();
    }
  }

  Map<String, dynamic> _serialized() => {
    'score': _score,
    'merges': _merges,
    'stage': _stage,
    'charges': _powerCharges,
    'planetMass': _planetMass,
    'expandedCaptures': _expandedCaptures,
    'focusedCaptures': _focusedCaptures,
    'orbs': [
      for (final orb in _orbs)
        {
          'mass': orb.mass,
          'kind': orb.kind,
          'power': orb.isPower,
          'powerType': orb.power?.name,
          'x': orb.x,
          'y': orb.y,
          'drift': orb.drift,
        },
    ],
  };

  void _save() => unawaited(_store.writeSave(_serialized()));

  bool _hydrate(Map<String, dynamic> data) {
    final rawOrbs = data['orbs'];
    if (rawOrbs is! List || rawOrbs.isEmpty || rawOrbs.length > 250) {
      return false;
    }
    final restored = <LumaOrb>[];
    for (final entry in rawOrbs) {
      if (entry is! Map) return false;
      final mass = entry['mass'];
      final kind = entry['kind'];
      final x = entry['x'];
      final y = entry['y'];
      final drift = entry['drift'];
      final power = entry['power'];
      final powerType = entry['powerType'];
      if (mass is! num ||
          kind is! int ||
          x is! num ||
          y is! num ||
          drift is! num ||
          mass <= 0 ||
          kind < 0 ||
          kind > 5 ||
          (power != null && power is! bool)) {
        return false;
      }
      restored.add(
        LumaOrb(
          id: _nextId++,
          mass: mass.toDouble(),
          kind: kind,
          isPower: power == true,
          power: switch (powerType) {
            'expandField' => LumaWellPower.expandField,
            'focusField' => LumaWellPower.focusField,
            _ => null,
          },
          x: x.toDouble(),
          y: y.toDouble(),
          drift: drift.toDouble(),
        ),
      );
    }
    final score = data['score'];
    final merges = data['merges'];
    final stage = data['stage'];
    final charges = data['charges'];
    final planetMass = data['planetMass'];
    if (score is! int ||
        merges is! int ||
        stage is! int ||
        charges is! int ||
        planetMass is! num ||
        score < 0 ||
        merges < 0 ||
        stage < 1 ||
        charges < 0 ||
        planetMass < 4) {
      return false;
    }
    _orbs
      ..clear()
      ..addAll(restored);
    _score = score;
    _merges = merges;
    _stage = stage;
    _powerCharges = charges;
    _planetMass = planetMass.toDouble();
    _expandedCaptures = data['expandedCaptures'] is int
        ? data['expandedCaptures'] as int
        : 0;
    _focusedCaptures = data['focusedCaptures'] is int
        ? data['focusedCaptures'] as int
        : 0;
    return true;
  }

  void _spawn() {
    final angle = _random.nextDouble() * math.pi * 2;
    final distance = 0.42 + _random.nextDouble() * 0.8;
    final isPower = _random.nextInt(18) == 0;
    final powerType = isPower ? _random.nextInt(3) : -1;
    _orbs.add(
      LumaOrb(
        id: _nextId++,
        mass: (1 + _random.nextInt(3)).toDouble(),
        kind: _random.nextInt(highestUnlockedNumber),
        isPower: isPower,
        power: switch (powerType) {
          1 => LumaWellPower.expandField,
          2 => LumaWellPower.focusField,
          _ => null,
        },
        x: math.cos(angle) * distance,
        y: math.sin(angle) * distance,
        drift: (_random.nextDouble() - 0.5) * 0.16,
      ),
    );
  }
}
