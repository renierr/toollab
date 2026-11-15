import 'package:flutter/material.dart';

import 'video_backend.dart';

/// The video fitted to its aspect ratio, zoomed and panned, or the error.
class VideoSurface extends StatelessWidget {
  final GlobalKey frameKey;
  final VideoPlaybackState state;
  final double zoom;
  final Offset pan;
  final Widget view;
  final String errorLabel;

  const VideoSurface({
    super.key,
    required this.frameKey,
    required this.state,
    required this.zoom,
    required this.pan,
    required this.view,
    required this.errorLabel,
  });

  @override
  Widget build(BuildContext context) {
    if (state.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            errorLabel,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRect(
          child: Transform.translate(
            offset: pan,
            child: Transform.scale(
              scale: zoom,
              child: Center(
                child: AspectRatio(
                  aspectRatio: state.aspectRatio,
                  child: RepaintBoundary(key: frameKey, child: view),
                ),
              ),
            ),
          ),
        ),
        if (!state.initialized || state.buffering)
          const Center(child: CircularProgressIndicator()),
      ],
    );
  }
}
