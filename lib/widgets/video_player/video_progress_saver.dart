import 'dart:async';

import 'video_backend.dart';
import 'video_resume_store.dart';

/// Writes where the video was left: throttled while playing, at once when
/// playback starts, pauses or ends, or when [save] is forced.
class VideoProgressSaver {
  static const Duration interval = Duration(seconds: 5);

  final VideoResumeStore store;
  DateTime _last = DateTime(0);
  bool _playing = false;

  VideoProgressSaver(this.store);

  /// The next save goes through, e.g. for a new video.
  void reset() => _last = DateTime(0);

  void save({
    required Uri source,
    required String title,
    required VideoPlaybackState state,
    bool force = false,
  }) {
    if (!state.initialized || state.duration <= Duration.zero) return;
    final now = DateTime.now();
    if (!force &&
        state.playing == _playing &&
        !state.completed &&
        now.difference(_last) < interval) {
      return;
    }
    _last = now;
    _playing = state.playing;
    unawaited(
      store.savePosition(
        source: source,
        title: title,
        position: state.completed ? state.duration : state.position,
        duration: state.duration,
      ),
    );
  }
}
