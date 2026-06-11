import 'package:flutter/material.dart';

import '../chiptune_colors.dart';

/// A row of LEDs reflecting per-channel playback activity.
class ChiptuneChannelActivity extends StatelessWidget {
  final List<bool> active;
  const ChiptuneChannelActivity({super.key, required this.active});

  @override
  Widget build(BuildContext context) {
    if (active.isEmpty) {
      return Text(
        'No file loaded',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontStyle: FontStyle.italic,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (int i = 0; i < active.length; i++)
          _Led(on: active[i], index: i + 1),
      ],
    );
  }
}

class _Led extends StatelessWidget {
  final bool on;
  final int index;
  const _Led({required this.on, required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: on ? ChiptuneColors.ledOn : ChiptuneColors.ledOff,
        borderRadius: BorderRadius.circular(4),
        boxShadow: on
            ? [
                BoxShadow(
                  color: ChiptuneColors.ledOn.withValues(alpha: 0.6),
                  blurRadius: 6,
                ),
              ]
            : null,
      ),
      child: Text(
        '$index',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: on ? ChiptuneColors.ledTextOn : ChiptuneColors.ledTextOff,
        ),
      ),
    );
  }
}
