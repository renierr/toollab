import 'package:flutter/foundation.dart';
import 'package:tool_lab/services/database_service.dart';

import 'config.dart';

/// Persisted calibration settings for the bubble level. Live sensor values
/// stay in the page — only user-calibrated values are stored here.
class BubbleLevelState extends ChangeNotifier {
  static String get _toolId => BubbleLevelTool.config.id;

  double _tolerance = 0.2;
  double _pxPerMm = 3.78;

  double get tolerance => _tolerance;
  double get pxPerMm => _pxPerMm;

  Future<void> restore() async {
    final db = DatabaseService.instance;
    final px = await db.getSetting(_toolId, 'pxPerMm');
    final tol = await db.getSetting(_toolId, 'tolerance');
    if (px != null) _pxPerMm = double.tryParse(px) ?? _pxPerMm;
    if (tol != null) _tolerance = double.tryParse(tol) ?? _tolerance;
    notifyListeners();
  }

  void setTolerance(double v) {
    _tolerance = v;
    notifyListeners();
    DatabaseService.instance.setSetting(
      _toolId,
      'tolerance',
      v.toStringAsFixed(2),
    );
  }

  void setPxPerMm(double v) {
    _pxPerMm = v;
    notifyListeners();
    DatabaseService.instance.setSetting(
      _toolId,
      'pxPerMm',
      v.toStringAsFixed(4),
    );
  }
}
