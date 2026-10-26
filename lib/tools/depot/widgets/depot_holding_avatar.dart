import 'package:flutter/material.dart';

import '../depot_colors.dart';

/// Rounded initials badge, colored per holding.
class DepotHoldingAvatar extends StatelessWidget {
  final String name;
  final String colorSeed;
  final double size;

  const DepotHoldingAvatar({
    super.key,
    required this.name,
    required this.colorSeed,
    this.size = 32,
  });

  static String _initials(String name) {
    final words = name
        .split(RegExp(r'[\s\-&.,/]+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    final first = words.first.characters.first;
    if (words.length == 1) return first.toUpperCase();
    return (first + words[1].characters.first).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final color = DepotColors.holding(colorSeed);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(size / 4),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        _initials(name),
        style: TextStyle(
          color: color,
          fontSize: size * 0.375,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
