import 'package:flutter/material.dart';

import '../chiptune_colors.dart';

/// Playback controls: play/pause, stop, loop, volume.
class ChiptuneTransportBar extends StatelessWidget {
  final bool isPlaying;
  final bool looping;
  final double volume;
  final VoidCallback onPlayPause;
  final VoidCallback onStop;
  final ValueChanged<bool> onLoopChanged;
  final ValueChanged<double> onVolumeChanged;

  const ChiptuneTransportBar({
    super.key,
    required this.isPlaying,
    required this.looping,
    required this.volume,
    required this.onPlayPause,
    required this.onStop,
    required this.onLoopChanged,
    required this.onVolumeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        IconButton.filled(
          onPressed: onPlayPause,
          icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
          style: IconButton.styleFrom(backgroundColor: ChiptuneColors.accent),
          tooltip: isPlaying ? 'Pause' : 'Play',
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: onStop,
          icon: const Icon(Icons.stop),
          tooltip: 'Stop',
        ),
        IconButton(
          onPressed: () => onLoopChanged(!looping),
          icon: Icon(
            Icons.repeat,
            color: looping ? ChiptuneColors.accentBright : null,
          ),
          tooltip: looping ? 'Looping' : 'Loop off',
        ),
        const SizedBox(width: 8),
        Icon(
          volume <= 0 ? Icons.volume_off : Icons.volume_up,
          size: 18,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        Expanded(
          child: Slider(
            value: volume.clamp(0.0, 1.0),
            activeColor: ChiptuneColors.accent,
            onChanged: onVolumeChanged,
          ),
        ),
      ],
    );
  }
}
