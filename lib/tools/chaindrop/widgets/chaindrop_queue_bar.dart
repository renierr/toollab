import 'package:flutter/material.dart';

import '../chaindrop_colors.dart';

/// The upcoming three discs, front one emphasized as next to drop.
class ChainDropQueueBar extends StatelessWidget {
  final List<int> queue;

  const ChainDropQueueBar({super.key, required this.queue});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ChainDropColors.board.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < queue.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: _QueueDisc(value: queue[i], emphasized: i == 0),
              ),
          ],
        ),
      ),
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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(ChainDropColors.forValue(value), Colors.white, 0.2)!,
            ChainDropColors.forValue(value),
          ],
        ),
        shape: BoxShape.circle,
        border: emphasized
            ? Border.all(color: Colors.white.withValues(alpha: 0.85), width: 2)
            : Border.all(color: Colors.white.withValues(alpha: 0.16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
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
