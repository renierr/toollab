import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../chiptune_colors.dart';

/// Playback controls: play/pause, stop, loop, volume.
class ChiptuneTransportBar extends StatelessWidget {
  final bool isPlaying;
  final bool looping;
  final double volume;
  final VoidCallback onPlayPause;
  final VoidCallback onStop;

  /// When non-null (random mode), shows a skip-to-next-random-tune button.
  final VoidCallback? onNext;
  final ValueChanged<bool> onLoopChanged;
  final ValueChanged<double> onVolumeChanged;

  const ChiptuneTransportBar({
    super.key,
    required this.isPlaying,
    required this.looping,
    required this.volume,
    required this.onPlayPause,
    required this.onStop,
    this.onNext,
    required this.onLoopChanged,
    required this.onVolumeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Row(
      children: [
        IconButton.filled(
          onPressed: onPlayPause,
          icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
          style: IconButton.styleFrom(backgroundColor: ChiptuneColors.accent),
          tooltip: isPlaying ? l10n.chipPauseTooltip : l10n.chipPlayTooltip,
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: onStop,
          icon: const Icon(Icons.stop),
          tooltip: l10n.chipStopTooltip,
        ),
        if (onNext != null)
          IconButton(
            onPressed: onNext,
            icon: const Icon(Icons.skip_next),
            tooltip: l10n.chipNextRandomTooltip,
          ),
        IconButton(
          onPressed: () => onLoopChanged(!looping),
          icon: Icon(
            Icons.repeat,
            color: looping ? ChiptuneColors.accentBright : null,
          ),
          tooltip: looping ? l10n.chipLoopingTooltip : l10n.chipLoopOffTooltip,
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
