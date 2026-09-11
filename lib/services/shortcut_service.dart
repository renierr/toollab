import 'dart:async';
import 'package:tool_lab/helpers/debug_log.dart';
import 'dart:io';
import 'package:flutter/services.dart';

class ShortcutService {
  static const _channel = MethodChannel('de.renier.tool_lab/shortcuts');

  static final ShortcutService instance = ShortcutService._();

  ShortcutService._() {
    if (Platform.isAndroid) {
      _channel.setMethodCallHandler(_handleMethodCall);
    }
  }

  late final StreamController<String> _routeStreamController =
      StreamController<String>.broadcast(onListen: _flushPendingRoute);

  /// A broadcast stream drops events that arrive before the first listener, and
  /// native may push a route while the app is still booting.
  String? _pendingRoute;

  Stream<String> get onShortcutRoute => _routeStreamController.stream;

  void _flushPendingRoute() {
    final route = _pendingRoute;
    if (route == null) return;
    _pendingRoute = null;
    scheduleMicrotask(() => _routeStreamController.add(route));
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onShortcutRoute') {
      final route = call.arguments as String?;
      if (route == null) return;
      if (_routeStreamController.hasListener) {
        _routeStreamController.add(route);
      } else {
        _pendingRoute = route;
      }
    }
  }

  Future<String?> getLaunchRoute() async {
    if (!Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<String>('getLaunchRoute');
    } catch (e) {
      errorLog('[ShortcutService] Failed to get launch route: $e');
      return null;
    }
  }

  Future<bool> pinShortcut(String toolId, String toolName) async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('pinShortcut', {
            'id': toolId,
            'name': toolName,
          }) ??
          false;
    } catch (e) {
      errorLog('[ShortcutService] Failed to pin shortcut: $e');
      return false;
    }
  }

  Future<void> removeShortcut(String toolId) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('removeShortcut', {'id': toolId});
    } catch (e) {
      errorLog('[ShortcutService] Failed to remove shortcut: $e');
    }
  }

  Future<void> setDrawerIconEnabled(String toolId, bool enabled) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('setDrawerIconEnabled', {
        'id': toolId,
        'enabled': enabled,
      });
    } catch (e) {
      errorLog('[ShortcutService] Failed to set drawer icon: $e');
    }
  }
}
