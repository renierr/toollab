import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:tool_lab/services/database_service.dart';

import 'config.dart';

enum LumaWellTouchOffsetDirection {
  none,
  north,
  northEast,
  east,
  southEast,
  south,
  southWest,
  west,
  northWest;

  Offset get vector => switch (this) {
    LumaWellTouchOffsetDirection.none => Offset.zero,
    LumaWellTouchOffsetDirection.north => const Offset(0, -1),
    LumaWellTouchOffsetDirection.northEast => const Offset(0.7071, -0.7071),
    LumaWellTouchOffsetDirection.east => const Offset(1, 0),
    LumaWellTouchOffsetDirection.southEast => const Offset(0.7071, 0.7071),
    LumaWellTouchOffsetDirection.south => const Offset(0, 1),
    LumaWellTouchOffsetDirection.southWest => const Offset(-0.7071, 0.7071),
    LumaWellTouchOffsetDirection.west => const Offset(-1, 0),
    LumaWellTouchOffsetDirection.northWest => const Offset(-0.7071, -0.7071),
  };
}

class LumaWellState extends ChangeNotifier {
  static const String _hapticsKey = 'haptics_enabled';
  static const String _easyModeKey = 'easy_mode';
  static const String _unlimitedPowersKey = 'unlimited_powers';
  static const String _captureTimeKey = 'capture_time';
  static const String _touchOffsetDirectionKey = 'touch_offset_direction';
  static const String _touchOffsetDistanceKey = 'touch_offset_distance';
  static const double _defaultTouchOffsetDistance = 60;

  bool _hapticsEnabled = true;
  bool _easyMode = false;
  bool _unlimitedPowers = false;
  double _captureTime = 1.5;
  LumaWellTouchOffsetDirection _touchOffsetDirection =
      LumaWellTouchOffsetDirection.none;
  double _touchOffsetDistance = _defaultTouchOffsetDistance;

  bool get hapticsEnabled => _hapticsEnabled;
  bool get easyMode => _easyMode;
  bool get unlimitedPowers => _unlimitedPowers;
  double get captureTime => _captureTime;
  LumaWellTouchOffsetDirection get touchOffsetDirection =>
      _touchOffsetDirection;
  double get touchOffsetDistance => _touchOffsetDistance;

  Future<void> restore() async {
    _hapticsEnabled =
        (await DatabaseService.instance.getSetting(
          LumaWellTool.config.id,
          _hapticsKey,
        )) !=
        'false';
    _easyMode =
        (await DatabaseService.instance.getSetting(
          LumaWellTool.config.id,
          _easyModeKey,
        )) ==
        'true';
    _unlimitedPowers =
        (await DatabaseService.instance.getSetting(
          LumaWellTool.config.id,
          _unlimitedPowersKey,
        )) ==
        'true';
    final captureTime = double.tryParse(
      await DatabaseService.instance.getSetting(
            LumaWellTool.config.id,
            _captureTimeKey,
          ) ??
          '',
    );
    _captureTime =
        captureTime == 1.0 || captureTime == 1.5 || captureTime == 2.0
        ? captureTime!
        : 1.5;
    final touchOffsetDirectionName = await DatabaseService.instance.getSetting(
      LumaWellTool.config.id,
      _touchOffsetDirectionKey,
    );
    _touchOffsetDirection = LumaWellTouchOffsetDirection.values.firstWhere(
      (direction) => direction.name == touchOffsetDirectionName,
      orElse: () => LumaWellTouchOffsetDirection.none,
    );
    final touchOffsetDistance = double.tryParse(
      await DatabaseService.instance.getSetting(
            LumaWellTool.config.id,
            _touchOffsetDistanceKey,
          ) ??
          '',
    );
    _touchOffsetDistance =
        touchOffsetDistance != null &&
            touchOffsetDistance >= 0 &&
            touchOffsetDistance <= 120
        ? touchOffsetDistance
        : _defaultTouchOffsetDistance;
    notifyListeners();
  }

  Future<void> setHapticsEnabled(bool value) async {
    if (_hapticsEnabled == value) return;
    _hapticsEnabled = value;
    notifyListeners();
    await DatabaseService.instance.setSetting(
      LumaWellTool.config.id,
      _hapticsKey,
      value.toString(),
    );
  }

  Future<void> setEasyMode(bool value) async {
    if (_easyMode == value) return;
    _easyMode = value;
    notifyListeners();
    await DatabaseService.instance.setSetting(
      LumaWellTool.config.id,
      _easyModeKey,
      value.toString(),
    );
  }

  Future<void> setUnlimitedPowers(bool value) async {
    if (_unlimitedPowers == value) return;
    _unlimitedPowers = value;
    notifyListeners();
    await DatabaseService.instance.setSetting(
      LumaWellTool.config.id,
      _unlimitedPowersKey,
      value.toString(),
    );
  }

  Future<void> setCaptureTime(double value) async {
    if (value != 1.0 && value != 1.5 && value != 2.0) return;
    if (_captureTime == value) return;
    _captureTime = value;
    notifyListeners();
    await DatabaseService.instance.setSetting(
      LumaWellTool.config.id,
      _captureTimeKey,
      value.toString(),
    );
  }

  Future<void> setTouchOffsetDirection(
    LumaWellTouchOffsetDirection value,
  ) async {
    if (_touchOffsetDirection == value) return;
    _touchOffsetDirection = value;
    notifyListeners();
    await DatabaseService.instance.setSetting(
      LumaWellTool.config.id,
      _touchOffsetDirectionKey,
      value.name,
    );
  }

  Future<void> setTouchOffsetDistance(double value) async {
    final clamped = value.clamp(0.0, 120.0);
    if (_touchOffsetDistance == clamped) return;
    _touchOffsetDistance = clamped;
    notifyListeners();
    await DatabaseService.instance.setSetting(
      LumaWellTool.config.id,
      _touchOffsetDistanceKey,
      clamped.toString(),
    );
  }
}
