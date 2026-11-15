import 'dart:async';

import 'package:flutter/foundation.dart';

import 'video_backend.dart';

/// Calls [onStall] when playback stays loading too long, or fails or ends
/// early before reaching [resumeAt]: X serves some replay segments only at
/// lower qualities, so a seek can stall forever on the chosen one.
class VideoStallWatchdog {
  static const Duration limit = Duration(seconds: 8);
  static const Duration _nearEnd = Duration(seconds: 10);

  final VoidCallback onStall;
  Timer? _timer;

  /// Where playback should continue; cleared once it plays.
  Duration? resumeAt;

  VideoStallWatchdog({required this.onStall});

  void watch(VideoPlaybackState state) {
    final target = resumeAt;
    if (target != null) {
      final nearEnd =
          state.duration > Duration.zero && state.duration - target < _nearEnd;
      if (state.error != null || (state.completed && !nearEnd)) {
        _fire();
        return;
      }
    }
    final loading = !state.initialized || state.buffering;
    if (!loading || state.error != null) {
      cancel();
      if (state.playing && state.initialized) resumeAt = null;
      return;
    }
    _timer ??= Timer(limit, _fire);
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  void _fire() {
    cancel();
    onStall();
  }
}
