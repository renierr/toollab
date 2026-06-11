import 'package:flutter/services.dart';

enum WakeLockType { partial, full }

class WakeLockLease {
  WakeLockLease._(this._id, this.type);

  final int _id;
  final WakeLockType type;
  bool _released = false;

  Future<void> release() async {
    if (_released) return;
    _released = true;
    await PowerWakeLockService._releaseLease(_id, type);
  }
}

class PowerWakeLockService {
  PowerWakeLockService._();

  static const MethodChannel _channel = MethodChannel(
    'de.renier.tool_lab/wake_lock',
  );

  static final Set<int> _partialLeaseIds = <int>{};
  static final Set<int> _fullLeaseIds = <int>{};
  static int _nextLeaseId = 1;

  static bool get isPartialHeld => _partialLeaseIds.isNotEmpty;
  static bool get isFullHeld => _fullLeaseIds.isNotEmpty;

  static Future<WakeLockLease> acquirePartial() async {
    final int leaseId = _nextLeaseId++;
    if (_partialLeaseIds.isEmpty) {
      await _invoke('acquirePartial');
    }
    _partialLeaseIds.add(leaseId);
    return WakeLockLease._(leaseId, WakeLockType.partial);
  }

  static Future<WakeLockLease> acquireFull() async {
    final int leaseId = _nextLeaseId++;
    if (_fullLeaseIds.isEmpty) {
      await _invoke('acquireFull');
    }
    _fullLeaseIds.add(leaseId);
    return WakeLockLease._(leaseId, WakeLockType.full);
  }

  static Future<void> releaseAll() async {
    _partialLeaseIds.clear();
    _fullLeaseIds.clear();
    await _invoke('releasePartial');
    await _invoke('releaseFull');
  }

  static Future<void> _releaseLease(int leaseId, WakeLockType type) async {
    if (type == WakeLockType.partial) {
      _partialLeaseIds.remove(leaseId);
      if (_partialLeaseIds.isEmpty) {
        await _invoke('releasePartial');
      }
      return;
    }

    _fullLeaseIds.remove(leaseId);
    if (_fullLeaseIds.isEmpty) {
      await _invoke('releaseFull');
    }
  }

  static Future<void> _invoke(String method) async {
    try {
      await _channel.invokeMethod<void>(method);
    } catch (_) {
      // Unsupported platform/channel: no-op.
    }
  }
}
