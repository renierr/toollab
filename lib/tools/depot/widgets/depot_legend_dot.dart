import 'package:flutter/material.dart';

/// A colour dot with a label, for the legends under a chart.
class DepotLegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const DepotLegendDot({super.key, required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}
