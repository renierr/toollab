import 'package:flutter/material.dart';

class SignalStrengthIndicator extends StatelessWidget {
  final int bars;

  const SignalStrengthIndicator({super.key, required this.bars});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: List.generate(4, (i) {
        return Container(
          width: 4,
          height: 4 + i * 3,
          margin: const EdgeInsets.only(right: 1),
          decoration: BoxDecoration(
            color: i < bars
                ? theme.colorScheme.primary
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(1),
          ),
        );
      }),
    );
  }
}
