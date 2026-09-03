import 'package:flutter/foundation.dart';
import 'package:tool_lab/services/database_service.dart';

import 'config.dart';

class DriftBloomState extends ChangeNotifier {
  static const String _bestKey = 'best';
  static const String _hapticsKey = 'haptics_enabled';
  static const String _easyModeKey = 'easy_mode';
  static const String _ringLifeKey = 'ring_life';

  int _best = 0;
  bool _hapticsEnabled = true;
  bool _easyMode = false;
  double _ringLife = 10;

  int get best => _best;
  bool get hapticsEnabled => _hapticsEnabled;
  bool get easyMode => _easyMode;
  double get ringLife => _ringLife;

  Future<void> restore() async {
    _best =
        int.tryParse(
          await DatabaseService.instance.getSetting(
                DriftBloomTool.config.id,
                _bestKey,
              ) ??
              '',
        ) ??
        0;
    _hapticsEnabled =
        (await DatabaseService.instance.getSetting(
          DriftBloomTool.config.id,
          _hapticsKey,
        )) !=
        'false';
    _easyMode =
        (await DatabaseService.instance.getSetting(
          DriftBloomTool.config.id,
          _easyModeKey,
        )) ==
        'true';
    final ringLife = double.tryParse(
      await DatabaseService.instance.getSetting(
            DriftBloomTool.config.id,
            _ringLifeKey,
          ) ??
          '',
    );
    _ringLife = ringLife == 8 || ringLife == 10 || ringLife == 12
        ? ringLife!
        : 10;
    notifyListeners();
  }

  Future<void> saveBest(int value) async {
    if (value <= _best) return;
    _best = value;
    notifyListeners();
    await DatabaseService.instance.setSetting(
      DriftBloomTool.config.id,
      _bestKey,
      value.toString(),
    );
  }

  Future<void> setHapticsEnabled(bool value) async {
    if (_hapticsEnabled == value) return;
    _hapticsEnabled = value;
    notifyListeners();
    await DatabaseService.instance.setSetting(
      DriftBloomTool.config.id,
      _hapticsKey,
      value.toString(),
    );
  }

  Future<void> setEasyMode(bool value) async {
    if (_easyMode == value) return;
    _easyMode = value;
    notifyListeners();
    await DatabaseService.instance.setSetting(
      DriftBloomTool.config.id,
      _easyModeKey,
      value.toString(),
    );
  }

  Future<void> setRingLife(double value) async {
    if (value != 8 && value != 10 && value != 12) return;
    if (_ringLife == value) return;
    _ringLife = value;
    notifyListeners();
    await DatabaseService.instance.setSetting(
      DriftBloomTool.config.id,
      _ringLifeKey,
      value.toString(),
    );
  }
}
