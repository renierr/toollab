import 'dart:async';
import 'dart:typed_data';

import 'video_backend.dart';
import 'video_resume_store.dart';

/// Keeps a frame near where the video was left: on pause and every
/// [interval] while playing.
class VideoThumbnailer {
  static const Duration interval = Duration(minutes: 1);
  static const Duration _minPosition = Duration(seconds: 3);

  final VideoResumeStore store;
  DateTime _last = DateTime(0);
  bool _playing = false;
  bool _busy = false;

  VideoThumbnailer(this.store);

  /// The next playing state takes a frame, e.g. for a new video.
  void reset() {
    _last = DateTime(0);
    _playing = false;
  }

  void watch({
    required Uri source,
    required VideoPlaybackState state,
    required Future<Uint8List?> Function() capture,
  }) {
    final paused = _playing && !state.playing;
    _playing = state.playing;
    if (_busy ||
        !state.initialized ||
        state.completed ||
        state.position < _minPosition) {
      return;
    }
    final due = state.playing && DateTime.now().difference(_last) >= interval;
    if (!paused && !due) return;
    _last = DateTime.now();
    unawaited(_take(source, capture));
  }

  Future<void> _take(Uri source, Future<Uint8List?> Function() capture) async {
    _busy = true;
    try {
      final jpeg = await capture();
      if (jpeg != null) await store.saveThumbnail(source, jpeg);
    } finally {
      _busy = false;
    }
  }
}
