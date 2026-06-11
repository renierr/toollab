import 'dart:async';

import 'package:flutter/services.dart';

/// A reference-counted partial wake lock that keeps the CPU running without
/// keeping the screen on (Android) or a no-op on unsupported platforms.
///
/// Multiple callers can [acquire] independently; the platform wake lock is
/// held until every caller has [release]d.
class WakeLockService {
  WakeLockService._();

  static const _channel = MethodChannel('de.renier.tool_lab/wake_lock');

  static int _acquireCount = 0;

  /// Acquire a partial wake lock. Safe to call multiple times — only the
  /// first call actually acquires the platform lock.
  static Future<void> acquire() async {
    if (_acquireCount == 0) {
      try {
        await _channel.invokeMethod('acquire');
      } catch (_) {
        // Platform not supported — no-op.
      }
    }
    _acquireCount++;
  }

  /// Release one wake lock reference. The platform lock is released once all
  /// references are gone.
  static Future<void> release() async {
    _acquireCount = (_acquireCount - 1).clamp(0, _acquireCount);
    if (_acquireCount == 0) {
      try {
        await _channel.invokeMethod('release');
      } catch (_) {
        // Platform not supported — no-op.
      }
    }
  }

  /// Release all wake lock references immediately (use for lifecycle events).
  static Future<void> releaseAll() async {
    _acquireCount = 0;
    try {
      await _channel.invokeMethod('release');
    } catch (_) {
      // Platform not supported — no-op.
    }
  }
}
