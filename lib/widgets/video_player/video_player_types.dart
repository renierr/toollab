import 'package:flutter/widgets.dart';

import 'video_backend.dart';

class VideoPlayerAction {
  final IconData icon;
  final String label;
  final Future<void> Function(BuildContext context) onPressed;

  const VideoPlayerAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });
}

/// A rendition the viewer can switch to, e.g. one HLS variant.
class VideoQuality {
  final String label;
  final Uri source;

  /// A master playlist; never a stall fallback, mpv plays its best variant.
  final bool adaptive;

  const VideoQuality({
    required this.label,
    required this.source,
    this.adaptive = false,
  });
}

/// The next fixed quality below the one playing [source], if any.
VideoQuality? lowerVideoQuality(List<VideoQuality> qualities, Uri source) {
  final index = qualities.indexWhere((q) => q.source == source);
  if (index < 0) return null;
  return qualities.skip(index + 1).where((q) => !q.adaptive).firstOrNull;
}

typedef VideoProgressCallback =
    void Function(Uri source, VideoPlaybackState state);
