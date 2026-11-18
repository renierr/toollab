import 'dart:async';
import 'dart:io';

import 'package:tool_lab/services/foreground_runtime_service.dart';
import 'package:tool_lab/services/media_controls_service.dart';

import 'video_backend.dart';

/// The open video in the system's media controls: the Android media
/// notification, MPRIS on Linux and the media overlay on Windows.
class VideoMediaSession {
  String _title;
  final bool live;

  /// `play`, `pause`, `play_pause`, `rewind`, `forward`, `stop` or `seek:<ms>`.
  final void Function(String action) onAction;

  ForegroundRuntimeLease? _lease;
  bool _acquiring = false;
  bool _disposed = false;
  // ignore: cancel_subscriptions
  StreamSubscription<MediaButton>? _buttons;
  ({bool playing, Duration duration})? _sent;
  VideoPlaybackState? _latest;

  VideoMediaSession({
    required this._title,
    required this.live,
    required this.onAction,
  });

  String get title => _title;

  /// Resent with the next [sync].
  void retitle(String value) {
    _title = value;
    _sent = null;
  }

  /// Refreshes the controls when play state or length changes; the system
  /// extrapolates the position in between.
  Future<void> sync(VideoPlaybackState state) async {
    if (_disposed || !state.initialized) return;
    _latest = state;
    final next = (playing: state.playing, duration: state.duration);
    if (next == _sent) return;
    if (Platform.isAndroid) {
      await _syncNotification(state, next);
    } else {
      _sent = next;
      _syncDesktop(state);
    }
  }

  /// Moves the system progress bar after a jump.
  Future<void> seeked(Duration position, {required bool playing}) async {
    if (Platform.isAndroid) {
      await _lease?.updatePlayback(
        positionMs: position.inMilliseconds,
        playing: playing,
      );
    } else if (_buttons != null) {
      await MediaControlsService.instance.updatePosition(position);
    }
  }

  Future<void> _syncNotification(
    VideoPlaybackState state,
    ({bool playing, Duration duration}) next,
  ) async {
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

  void _syncDesktop(VideoPlaybackState state) {
    final controls = MediaControlsService.instance;
    _buttons ??= controls.buttonEvents.listen(
      (button) => onAction(switch (button) {
        MediaButton.play => 'play',
        MediaButton.pause => 'pause',
        MediaButton.stop => 'stop',
        // A single video has no next item; the keys skip instead.
        MediaButton.next => 'forward',
        MediaButton.previous => 'rewind',
      }),
    );
    unawaited(
      controls.updateMetadata(
        MediaMetadata(
          title: title,
          duration: live || state.duration <= Duration.zero
              ? null
              : state.duration,
          supportedButtons: [
            MediaButton.play,
            MediaButton.pause,
            MediaButton.stop,
            if (!live) ...[MediaButton.next, MediaButton.previous],
          ],
        ),
      ),
    );
    unawaited(
      controls.updatePlaybackStatus(
        state.playing
            ? MediaPlaybackStatus.playing
            : MediaPlaybackStatus.paused,
      ),
    );
    unawaited(controls.updatePosition(state.position));
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
    final buttons = _buttons;
    _buttons = null;
    if (buttons != null) {
      await buttons.cancel();
      await MediaControlsService.instance.clear();
    }
    final lease = _lease;
    _lease = null;
    lease?.removeActionListener();
    await lease?.release();
  }
}
