import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ShortcutService {
  static const _channel = MethodChannel('de.renier.tool_lab/shortcuts');

  static final ShortcutService instance = ShortcutService._();

  ShortcutService._() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  final _routeStreamController = StreamController<String>.broadcast();

  Stream<String> get onShortcutRoute => _routeStreamController.stream;

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onShortcutRoute') {
      final route = call.arguments as String?;
      if (route != null) {
        _routeStreamController.add(route);
      }
    }
  }

  Future<String?> getLaunchRoute() async {
    try {
      return await _channel.invokeMethod<String>('getLaunchRoute');
    } catch (e) {
      debugPrint('[ShortcutService] Failed to get launch route: $e');
      return null;
    }
  }

  Future<bool> pinShortcut(String toolId, String toolName) async {
    try {
      return await _channel.invokeMethod<bool>('pinShortcut', {
            'id': toolId,
            'name': toolName,
          }) ??
          false;
    } catch (e) {
      debugPrint('[ShortcutService] Failed to pin shortcut: $e');
      return false;
    }
  }

  Future<void> removeShortcut(String toolId) async {
    try {
      await _channel.invokeMethod('removeShortcut', {'id': toolId});
    } catch (e) {
      debugPrint('[ShortcutService] Failed to remove shortcut: $e');
    }
  }

  Future<void> setDrawerIconEnabled(String toolId, bool enabled) async {
    try {
      await _channel.invokeMethod('setDrawerIconEnabled', {
        'id': toolId,
        'enabled': enabled,
      });
    } catch (e) {
      debugPrint('[ShortcutService] Failed to set drawer icon: $e');
    }
  }
}
