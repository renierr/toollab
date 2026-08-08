import 'package:flutter/foundation.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:flutter/services.dart';

class ForegroundRuntimeLease {
  ForegroundRuntimeLease._(
    this._id, {
    required this.title,
    required this.text,
    this.actions,
  });

  final int _id;
  final String title;
  final String text;
  final List<String>? actions;
  bool _released = false;

  Future<void> release() async {
    if (_released) return;
    _released = true;
    await ForegroundRuntimeService._releaseLease(_id);
  }

  Future<void> update({
    required String title,
    required String text,
    List<String>? actions,
  }) async {
    if (_released) return;
    await ForegroundRuntimeService._updateLease(
      _id,
      title: title,
      text: text,
      actions: actions,
    );
  }
}

class ForegroundRuntimeService {
  ForegroundRuntimeService._();

  static const MethodChannel _channel = MethodChannel(
    'de.renier.tool_lab/foreground_runtime',
  );

  static final Map<int, ({String title, String text, List<String>? actions})>
  _activeLeases = <int, ({String title, String text, List<String>? actions})>{};
  static int _nextLeaseId = 1;

  static final List<void Function(String action)> _actionListeners = [];

  static bool get isActive => _activeLeases.isNotEmpty;

  static void addActionListener(void Function(String action) listener) {
    if (_actionListeners.isEmpty) {
      _channel.setMethodCallHandler(_handleMethodCall);
    }
    _actionListeners.add(listener);
  }

  static void removeActionListener(void Function(String action) listener) {
    _actionListeners.remove(listener);
    if (_actionListeners.isEmpty) {
      _channel.setMethodCallHandler(null);
    }
  }

  static Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onAction') {
      final action = call.arguments as String;
      for (final listener in List.of(_actionListeners)) {
        listener(action);
      }
    }
  }

  static Future<bool> requestNotificationPermission() async {
    if (defaultTargetPlatform != TargetPlatform.android) return true;
    try {
      final ok = await _channel.invokeMethod<bool>(
        'requestNotificationPermission',
      );
      return ok ?? true;
    } catch (e) {
      errorLog('[$_logPrefix] requestNotificationPermission failed: $e');
      return true;
    }
  }

  static Future<ForegroundRuntimeLease> acquire({
    required String title,
    required String text,
    List<String>? actions,
  }) async {
    await requestNotificationPermission();
    final int leaseId = _nextLeaseId++;
    final bool wasInactive = _activeLeases.isEmpty;
    _activeLeases[leaseId] = (title: title, text: text, actions: actions);
    if (wasInactive) {
      await _invoke('start', {
        'title': title,
        'text': text,
        'actions': actions,
      });
    } else {
      await _invoke('update', {
        'title': title,
        'text': text,
        'actions': actions,
      });
    }
    return ForegroundRuntimeLease._(
      leaseId,
      title: title,
      text: text,
      actions: actions,
    );
  }

  static Future<void> releaseAll() async {
    _activeLeases.clear();
    await _invoke('stop');
  }

  static Future<void> _updateLease(
    int leaseId, {
    required String title,
    required String text,
    List<String>? actions,
  }) async {
    if (!_activeLeases.containsKey(leaseId)) return;
    _activeLeases[leaseId] = (title: title, text: text, actions: actions);
    await _invoke('update', {'title': title, 'text': text, 'actions': actions});
  }

  static Future<void> _releaseLease(int leaseId) async {
    if (!_activeLeases.containsKey(leaseId)) return;
    _activeLeases.remove(leaseId);

    if (_activeLeases.isEmpty) {
      await _invoke('stop');
      return;
    }

    final latest = _activeLeases.values.last;
    await _invoke('update', {
      'title': latest.title,
      'text': latest.text,
      'actions': latest.actions,
    });
  }

  static Future<void> _invoke(
    String method, [
    Map<String, Object?> arguments = const <String, Object?>{},
  ]) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } catch (e) {
      errorLog('[$_logPrefix] _invoke($method) failed: $e');
    }
  }

  static const String _logPrefix = 'ForegroundRuntimeService';
}
