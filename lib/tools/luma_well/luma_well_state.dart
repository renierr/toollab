import 'package:flutter/foundation.dart';
import 'package:tool_lab/services/database_service.dart';

import 'config.dart';

class LumaWellState extends ChangeNotifier {
  static const String _hapticsKey = 'haptics_enabled';
  static const String _easyModeKey = 'easy_mode';

  bool _hapticsEnabled = true;
  bool _easyMode = false;

  bool get hapticsEnabled => _hapticsEnabled;
  bool get easyMode => _easyMode;

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
}
