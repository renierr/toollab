import 'package:flutter/foundation.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:flutter/services.dart';

/// Media-session payload for a lease. When set, the Android notification is
/// rendered as a MediaStyle notification with metadata, a live progress bar
/// (extrapolated from position + playing) and seek support.
///
/// Leave [durationMs] null for endless audio (noise generators): the session
/// still gets media treatment without a seek bar.
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
  int? chronometerSinceMs,
  int? progress,
  int? progressMax,
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

  /// [chronometerSinceMs] shows a system-rendered ticking timer since that
  /// epoch timestamp (pass null to clear). [progress]/[progressMax] show a
  /// determinate progress bar.
  Future<void> update({
    required String title,
    required String text,
    List<String>? actions,
    MediaNotificationData? media,
    int? chronometerSinceMs,
    int? progress,
    int? progressMax,
  }) async {
    if (_released) return;
    await ForegroundRuntimeService._updateLease(
      _id,
      title: title,
      text: text,
      actions: actions,
      media: media,
      chronometerSinceMs: chronometerSinceMs,
      progress: progress,
      progressMax: progressMax,
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
    await ForegroundRuntimeService._updatePlayback(
      _id,
      positionMs: positionMs,
      playing: playing,
    );
  }

  void addActionListener(void Function(String action) listener) {
    if (_released) return;
    ForegroundRuntimeService._addActionListener(_id, listener);
  }

  void removeActionListener() {
    ForegroundRuntimeService._removeActionListener(_id);
  }
}

class ForegroundRuntimeService {
  ForegroundRuntimeService._();

  static const MethodChannel _channel = MethodChannel(
    'de.renier.tool_lab/foreground_runtime',
  );

  static final Map<int, _LeaseSnapshot> _activeLeases = <int, _LeaseSnapshot>{};
  static int _nextLeaseId = 1;

  static final Map<int, void Function(String action)> _actionListeners =
      <int, void Function(String action)>{};

  static bool get isActive => _activeLeases.isNotEmpty;

  static void _addActionListener(
    int leaseId,
    void Function(String action) listener,
  ) {
    if (_actionListeners.isEmpty) {
      _channel.setMethodCallHandler(_handleMethodCall);
    }
    _actionListeners[leaseId] = listener;
  }

  static void _removeActionListener(int leaseId) {
    _actionListeners.remove(leaseId);
    if (_actionListeners.isEmpty) {
      _channel.setMethodCallHandler(null);
    }
  }

  static Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onAction') {
      final action = call.arguments as String;
      final leaseId = _activeLeases.keys.lastOrNull;
      final listener = leaseId == null ? null : _actionListeners[leaseId];
      listener?.call(action);
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
    int? chronometerSinceMs,
    int? progress,
    int? progressMax,
  }) async {
    await requestNotificationPermission();
    final int leaseId = _nextLeaseId++;
    final bool wasInactive = _activeLeases.isEmpty;
    final snapshot = (
      title: title,
      text: text,
      actions: actions,
      media: media,
      chronometerSinceMs: chronometerSinceMs,
      progress: progress,
      progressMax: progressMax,
    );
    _activeLeases
      ..remove(leaseId)
      ..[leaseId] = snapshot;
    await _invoke(wasInactive ? 'start' : 'update', _snapshotArgs(snapshot));
    return ForegroundRuntimeLease._(leaseId);
  }

  /// Position/state-only refresh of the active media session (no notification
  /// rebuild). No-op when no lease carries a [MediaNotificationData].
  static Future<void> _updatePlayback(
    int leaseId, {
    required int positionMs,
    required bool playing,
  }) async {
    if (_activeLeases.keys.lastOrNull != leaseId ||
        _activeLeases[leaseId]?.media == null) {
      return;
    }
    await _invoke('playbackState', {
      'positionMs': positionMs,
      'playing': playing,
    });
  }

  static Future<void> releaseAll() async {
    _activeLeases.clear();
    _actionListeners.clear();
    _channel.setMethodCallHandler(null);
    await _invoke('stop');
  }

  static Map<String, Object?> _snapshotArgs(_LeaseSnapshot s) => {
    'title': s.title,
    'text': s.text,
    'actions': s.actions,
    'media': s.media?.toMap(),
    'chronometerSinceMs': s.chronometerSinceMs,
    'progress': s.progress,
    'progressMax': s.progressMax,
  };

  static Future<void> _updateLease(
    int leaseId, {
    required String title,
    required String text,
    List<String>? actions,
    MediaNotificationData? media,
    int? chronometerSinceMs,
    int? progress,
    int? progressMax,
  }) async {
    if (!_activeLeases.containsKey(leaseId)) return;
    final snapshot = (
      title: title,
      text: text,
      actions: actions,
      media: media,
      chronometerSinceMs: chronometerSinceMs,
      progress: progress,
      progressMax: progressMax,
    );
    // A lease that refreshes its notification becomes the visible owner.
    _activeLeases
      ..remove(leaseId)
      ..[leaseId] = snapshot;
    await _invoke('update', _snapshotArgs(snapshot));
  }

  static Future<void> _releaseLease(int leaseId) async {
    if (!_activeLeases.containsKey(leaseId)) return;
    _activeLeases.remove(leaseId);
    _removeActionListener(leaseId);

    if (_activeLeases.isEmpty) {
      await _invoke('stop');
      return;
    }

    await _invoke('update', _snapshotArgs(_activeLeases.values.last));
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
