import 'package:flutter/material.dart';

import '../chaindrop_colors.dart';

/// The upcoming three discs, front one emphasized as next to drop.
class ChainDropQueueBar extends StatelessWidget {
  final List<int> queue;

  const ChainDropQueueBar({super.key, required this.queue});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < queue.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: _QueueDisc(value: queue[i], emphasized: i == 0),
          ),
      ],
    );
  }
}

class _QueueDisc extends StatelessWidget {
  final int value;
  final bool emphasized;

  const _QueueDisc({required this.value, required this.emphasized});

  @override
  Widget build(BuildContext context) {
    final size = emphasized ? 44.0 : 32.0;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: ChainDropColors.forValue(value),
        shape: BoxShape.circle,
        border: emphasized
            ? Border.all(color: Colors.white.withValues(alpha: 0.85), width: 2)
            : null,
      ),
      child: Text(
        '$value',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: emphasized ? 18 : 14,
        ),
      ),
    );
  }
}
