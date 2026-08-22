import 'package:flutter/foundation.dart';
import 'package:tool_lab/services/database_service.dart';

import 'config.dart';

/// Persisted QR scanner settings.
class QrCodeState extends ChangeNotifier {
  static String get _toolId => QrCodeTool.config.id;

  String _scannerEngine = 'zxing';

  /// `'zxing'` or `'mlkit'`.
  String get scannerEngine => _scannerEngine;

  Future<void> restore() async {
    final stored = await DatabaseService.instance.getSetting(
      _toolId,
      'scanner_engine',
    );
    if (stored != null) {
      _scannerEngine = stored;
      notifyListeners();
    }
  }

  void setScannerEngine(String engine) {
    _scannerEngine = engine;
    notifyListeners();
    DatabaseService.instance.setSetting(_toolId, 'scanner_engine', engine);
  }
}
