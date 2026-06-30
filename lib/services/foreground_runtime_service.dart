import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ForegroundRuntimeLease {
  ForegroundRuntimeLease._(this._id, {required this.title, required this.text});

  final int _id;
  final String title;
  final String text;
  bool _released = false;

  Future<void> release() async {
    if (_released) return;
    _released = true;
    await ForegroundRuntimeService._releaseLease(_id);
  }

  Future<void> update({required String title, required String text}) async {
    if (_released) return;
    await ForegroundRuntimeService._updateLease(_id, title: title, text: text);
  }
}

class ForegroundRuntimeService {
  ForegroundRuntimeService._();

  static const MethodChannel _channel = MethodChannel(
    'de.renier.tool_lab/foreground_runtime',
  );

  static final Map<int, ({String title, String text})> _activeLeases =
      <int, ({String title, String text})>{};
  static int _nextLeaseId = 1;

  static bool get isActive => _activeLeases.isNotEmpty;

  static Future<ForegroundRuntimeLease> acquire({
    required String title,
    required String text,
  }) async {
    final int leaseId = _nextLeaseId++;
    final bool wasInactive = _activeLeases.isEmpty;
    _activeLeases[leaseId] = (title: title, text: text);
    if (wasInactive) {
      await _invoke('start', {'title': title, 'text': text});
    } else {
      await _invoke('update', {'title': title, 'text': text});
    }
    return ForegroundRuntimeLease._(leaseId, title: title, text: text);
  }

  static Future<void> releaseAll() async {
    _activeLeases.clear();
    await _invoke('stop');
  }

  static Future<void> _updateLease(
    int leaseId, {
    required String title,
    required String text,
  }) async {
    if (!_activeLeases.containsKey(leaseId)) return;
    _activeLeases[leaseId] = (title: title, text: text);
    await _invoke('update', {'title': title, 'text': text});
  }

  static Future<void> _releaseLease(int leaseId) async {
    if (!_activeLeases.containsKey(leaseId)) return;
    _activeLeases.remove(leaseId);

    if (_activeLeases.isEmpty) {
      await _invoke('stop');
      return;
    }

    final ({String title, String text}) latest = _activeLeases.values.last;
    await _invoke('update', {'title': latest.title, 'text': latest.text});
  }

  static Future<void> _invoke(
    String method, [
    Map<String, Object?> arguments = const <String, Object?>{},
  ]) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } catch (_) {
      // Unsupported platform/channel: no-op.
    }
  }
}
