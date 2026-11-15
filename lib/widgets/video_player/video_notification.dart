import 'dart:async';
import 'dart:io';

import 'package:tool_lab/services/foreground_runtime_service.dart';

import 'video_backend.dart';

/// Android media notification for the open video player.
class VideoNotification {
  final String title;
  final bool live;
  final void Function(String action) onAction;

  ForegroundRuntimeLease? _lease;
  bool _acquiring = false;
  bool _disposed = false;
  ({bool playing, Duration duration})? _sent;
  VideoPlaybackState? _latest;

  VideoNotification({
    required this.title,
    required this.live,
    required this.onAction,
  });

  /// Rebuilds the notification when play state or length changes; the
  /// session extrapolates the position in between.
  Future<void> sync(VideoPlaybackState state) async {
    if (!Platform.isAndroid || _disposed || !state.initialized) return;
    _latest = state;
    final next = (playing: state.playing, duration: state.duration);
    if (next == _sent) return;
    final lease = _lease;
    if (lease == null) {
      if (_acquiring) return;
      _acquiring = true;
      final acquired = await ForegroundRuntimeService.acquire(
        title: title,
        text: '',
        actions: _actions(state.playing),
        media: _media(state),
        types: const {ForegroundServiceType.mediaPlayback},
      );
      _acquiring = false;
      if (_disposed) {
        await acquired.release();
        return;
      }
      acquired.addActionListener(onAction);
      _lease = acquired;
      _sent = next;
      // Catches a change that arrived while acquiring.
      await sync(_latest!);
      return;
    }
    _sent = next;
    await lease.update(
      title: title,
      text: '',
      actions: _actions(state.playing),
      media: _media(state),
    );
  }

  /// Moves the notification's progress bar after a jump.
  Future<void> seeked(Duration position, {required bool playing}) async {
    await _lease?.updatePlayback(
      positionMs: position.inMilliseconds,
      playing: playing,
    );
  }

  List<String> _actions(bool playing) => [
    if (!live) 'rewind',
    playing ? 'pause' : 'play',
    if (!live) 'forward',
    'stop',
  ];

  MediaNotificationData _media(VideoPlaybackState state) =>
      MediaNotificationData(
        title: title,
        durationMs: live || state.duration <= Duration.zero
            ? null
            : state.duration.inMilliseconds,
        positionMs: state.position.inMilliseconds,
        playing: state.playing,
        seekable: !live,
      );

  Future<void> dispose() async {
    _disposed = true;
    final lease = _lease;
    _lease = null;
    lease?.removeActionListener();
    await lease?.release();
  }
}
