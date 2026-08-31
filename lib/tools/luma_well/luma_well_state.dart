import 'package:flutter/foundation.dart';
import 'package:tool_lab/services/database_service.dart';

import 'config.dart';

class LumaWellState extends ChangeNotifier {
  static const String _hapticsKey = 'haptics_enabled';
  static const String _easyModeKey = 'easy_mode';
  static const String _unlimitedPowersKey = 'unlimited_powers';
  static const String _captureTimeKey = 'capture_time';

  bool _hapticsEnabled = true;
  bool _easyMode = false;
  bool _unlimitedPowers = false;
  double _captureTime = 1.5;

  bool get hapticsEnabled => _hapticsEnabled;
  bool get easyMode => _easyMode;
  bool get unlimitedPowers => _unlimitedPowers;
  double get captureTime => _captureTime;

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
}
