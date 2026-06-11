import 'package:flutter/material.dart';

import '../chiptune_colors.dart';
import '../engine/chiptune_player.dart';

/// Position read-out + seek slider based on the song's row timeline.
class ChiptuneSeekBar extends StatelessWidget {
  final SongPosition position;
  final Duration elapsed;
  final int rowsPerPattern;
  final int totalRows;
  final ValueChanged<double> onSeekFraction;

  const ChiptuneSeekBar({
    super.key,
    required this.position,
    required this.elapsed,
    required this.rowsPerPattern,
    required this.totalRows,
    required this.onSeekFraction,
  });

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentRow = position.order * rowsPerPattern + position.row;
    final fraction = (currentRow / totalRows).clamp(0.0, 1.0);
    final style = theme.textTheme.labelSmall?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
          ),
          child: Slider(
            value: fraction,
            activeColor: ChiptuneColors.accent,
            onChanged: onSeekFraction,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Pos ${position.order.toString().padLeft(2, '0')} · '
                'Row ${position.row.toString().padLeft(2, '0')}',
                style: style,
              ),
              Text(_fmt(elapsed), style: style),
            ],
          ),
        ),
      ],
    );
  }
}
