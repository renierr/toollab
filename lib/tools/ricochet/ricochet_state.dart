import 'package:flutter/foundation.dart';
import 'package:tool_lab/services/database_service.dart';

import 'config.dart';

class RicochetState extends ChangeNotifier {
  static const String _soundEnabledKey = 'sound_enabled';

  bool _soundEnabled = true;

  bool get soundEnabled => _soundEnabled;

  Future<void> restore() async {
    _soundEnabled =
        (await DatabaseService.instance.getSetting(
          RicochetTool.config.id,
          _soundEnabledKey,
        )) !=
        'false';
    notifyListeners();
  }

  Future<void> setSoundEnabled(bool value) async {
    if (_soundEnabled == value) return;
    _soundEnabled = value;
    notifyListeners();
    await DatabaseService.instance.setSetting(
      RicochetTool.config.id,
      _soundEnabledKey,
      value.toString(),
    );
  }
}
