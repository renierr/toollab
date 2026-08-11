import 'package:tool_lab/helpers/debug_log.dart';

import 'foreground_runtime_service.dart';
import 'power_wake_lock_service.dart';

/// A partial (CPU) wake lock plus a foreground notification, so long-running
/// work keeps going with the screen off instead of holding the display awake.
///
/// The notification is best-effort: a denied permission or missing channel
/// still leaves the wake lock held.
class BackgroundWorkLease {
  BackgroundWorkLease._(this._lock, this._notification, this.title);

  final WakeLockLease _lock;
  final ForegroundRuntimeLease? _notification;
  final String title;

  bool _released = false;
  int _lastUpdateMs = 0;

  static Future<BackgroundWorkLease> acquire({
    required String title,
    required String text,
    required String logPrefix,
  }) async {
    final lock = await PowerWakeLockService.acquirePartial();
    ForegroundRuntimeLease? notification;
    try {
      notification = await ForegroundRuntimeService.acquire(
        title: title,
        text: text,
      );
    } catch (e) {
      errorLog('[$logPrefix] Foreground notification unavailable: $e');
    }
    return BackgroundWorkLease._(lock, notification, title);
  }

  /// Rewrites the notification body. [minIntervalMs] throttles the platform
  /// channel round-trip so a byte-level progress callback can call this
  /// directly.
  Future<void> update(String text, {int minIntervalMs = 1000}) async {
    if (_released || _notification == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastUpdateMs < minIntervalMs) return;
    _lastUpdateMs = now;
    await _notification.update(title: title, text: text);
  }

  Future<void> release() async {
    if (_released) return;
    _released = true;
    await _notification?.release();
    await _lock.release();
  }
}
