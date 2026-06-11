import 'package:flutter/material.dart';

import '../chiptune_colors.dart';
import '../engine/chiptune_player.dart';
import 'chiptune_visualizer.dart';

/// Hosts the spectrum visualizer and collapses it to a slim strip while
/// playback is stopped or paused, expanding when audio is playing.
class ChiptuneVisualizerPanel extends StatelessWidget {
  static const double _collapsedHeight = 36;

  final ChiptunePlayer player;
  const ChiptuneVisualizerPanel({super.key, required this.player});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: player.state,
      builder: (context, state, _) {
        final playing = state == ChiptunePlaybackState.playing;
        final width = MediaQuery.sizeOf(context).width;
        final expandedHeight = (width * 6 / 16).clamp(80.0, 180.0);

        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: ColoredBox(
            color: ChiptuneColors.visualizerBg,
            child: AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: SizedBox(
                width: double.infinity,
                height: playing ? expandedHeight : _collapsedHeight,
                child: ChiptuneVisualizer(active: playing),
              ),
            ),
          ),
        );
      },
    );
  }
}
