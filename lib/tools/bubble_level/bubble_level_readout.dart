import 'package:flutter/material.dart';
import 'package:tool_lab/widgets/data_row.dart' as shared;

class BubbleLevelReadout extends StatelessWidget {
  final double pitch;
  final double roll;

  const BubbleLevelReadout({
    super.key,
    required this.pitch,
    required this.roll,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: shared.InfoRow(
            label: 'Pitch',
            value: '${pitch.toStringAsFixed(1)}°',
            vertical: true,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: shared.InfoRow(
            label: 'Roll',
            value: '${roll.toStringAsFixed(1)}°',
            vertical: true,
          ),
        ),
      ],
    );
  }
}
