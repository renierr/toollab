import 'package:flutter/foundation.dart';
import 'package:tool_lab/services/database_service.dart';

import 'config.dart';

/// The game's own settings menu: sound and haptics.
class ChainDropState extends ChangeNotifier {
  static const String _soundEnabledKey = 'sound_enabled';
  static const String _hapticsEnabledKey = 'haptics_enabled';

  bool _soundEnabled = true;
  bool _hapticsEnabled = true;

  bool get soundEnabled => _soundEnabled;
  bool get hapticsEnabled => _hapticsEnabled;

  Future<void> restore() async {
    _soundEnabled =
        (await DatabaseService.instance.getSetting(
          ChainDropTool.config.id,
          _soundEnabledKey,
        )) !=
        'false';
    _hapticsEnabled =
        (await DatabaseService.instance.getSetting(
          ChainDropTool.config.id,
          _hapticsEnabledKey,
        )) !=
        'false';
    notifyListeners();
  }

  Future<void> setSoundEnabled(bool value) async {
    if (_soundEnabled == value) return;
    _soundEnabled = value;
    notifyListeners();
    await DatabaseService.instance.setSetting(
      ChainDropTool.config.id,
      _soundEnabledKey,
      value.toString(),
    );
  }

  Future<void> setHapticsEnabled(bool value) async {
    if (_hapticsEnabled == value) return;
    _hapticsEnabled = value;
    notifyListeners();
    await DatabaseService.instance.setSetting(
      ChainDropTool.config.id,
      _hapticsEnabledKey,
      value.toString(),
    );
  }
}
