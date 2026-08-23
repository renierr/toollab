import 'package:flutter/foundation.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:flutter/services.dart';

/// Media-session payload for a lease. When set, the Android notification is
/// rendered as a MediaStyle notification with metadata, a live progress bar
/// (extrapolated from position + playing) and seek support.
class MediaNotificationData {
  final String title;
  final String? artist;
  final int? durationMs;
  final int positionMs;
  final bool playing;
  final bool seekable;

  const MediaNotificationData({
    required this.title,
    this.artist,
    this.durationMs,
    required this.positionMs,
    required this.playing,
    this.seekable = false,
  });

  Map<String, Object?> toMap() => <String, Object?>{
    'title': title,
    'artist': artist,
    'durationMs': durationMs,
    'positionMs': positionMs,
    'playing': playing,
    'seekable': seekable,
  };
}

typedef _LeaseSnapshot = ({
  String title,
  String text,
  List<String>? actions,
  MediaNotificationData? media,
});

class ForegroundRuntimeLease {
  ForegroundRuntimeLease._(this._id);

  final int _id;
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
    MediaNotificationData? media,
  }) async {
    if (_released) return;
    await ForegroundRuntimeService._updateLease(
      _id,
      title: title,
      text: text,
      actions: actions,
      media: media,
    );
  }

  /// Cheap position/state-only refresh. Updates the media session's playback
  /// state so the system-extrapolated progress bar stays accurate without
  /// rebuilding the notification.
  Future<void> updatePlayback({
    required int positionMs,
    required bool playing,
  }) async {
    if (_released) return;
    await ForegroundRuntimeService.updatePlayback(
      positionMs: positionMs,
      playing: playing,
    );
  }
}

class ForegroundRuntimeService {
  ForegroundRuntimeService._();

  static const MethodChannel _channel = MethodChannel(
    'de.renier.tool_lab/foreground_runtime',
  );

  static final Map<int, _LeaseSnapshot> _activeLeases = <int, _LeaseSnapshot>{};
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
    MediaNotificationData? media,
  }) async {
    await requestNotificationPermission();
    final int leaseId = _nextLeaseId++;
    final bool wasInactive = _activeLeases.isEmpty;
    final snapshot = (title: title, text: text, actions: actions, media: media);
    _activeLeases[leaseId] = snapshot;
    if (wasInactive) {
      await _invoke('start', {
        'title': title,
        'text': text,
        'actions': actions,
        'media': media?.toMap(),
      });
    } else {
      await _invoke('update', {
        'title': title,
        'text': text,
        'actions': actions,
        'media': media?.toMap(),
      });
    }
    return ForegroundRuntimeLease._(leaseId);
  }

  /// Position/state-only refresh of the active media session (no notification
  /// rebuild). No-op when no lease carries a [MediaNotificationData].
  static Future<void> updatePlayback({
    required int positionMs,
    required bool playing,
  }) async {
    if (!_activeLeases.values.any((s) => s.media != null)) return;
    await _invoke('playbackState', {
      'positionMs': positionMs,
      'playing': playing,
    });
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
    MediaNotificationData? media,
  }) async {
    if (!_activeLeases.containsKey(leaseId)) return;
    _activeLeases[leaseId] = (
      title: title,
      text: text,
      actions: actions,
      media: media,
    );
    await _invoke('update', {
      'title': title,
      'text': text,
      'actions': actions,
      'media': media?.toMap(),
    });
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
      'media': latest.media?.toMap(),
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
