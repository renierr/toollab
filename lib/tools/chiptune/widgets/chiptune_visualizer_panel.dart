import 'package:flutter/material.dart';

import '../chiptune_colors.dart';
import '../engine/chiptune_player.dart';
import 'chiptune_visualizer.dart';

/// Shows the spectrum visualizer while playing, hidden otherwise.
class ChiptuneVisualizerPanel extends StatelessWidget {
  final ChiptunePlayer player;
  const ChiptuneVisualizerPanel({super.key, required this.player});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: player.state,
      builder: (context, state, _) {
        if (state != ChiptunePlaybackState.playing) {
          return const SizedBox.shrink();
        }

        final width = MediaQuery.sizeOf(context).width;
        final height = (width * 6 / 16).clamp(80.0, 180.0);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ColoredBox(
                color: ChiptuneColors.visualizerBg,
                child: SizedBox(
                  width: double.infinity,
                  height: height,
                  child: const ChiptuneVisualizer(active: true),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }
}
