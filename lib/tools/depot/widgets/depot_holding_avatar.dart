import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../depot_colors.dart';
import '../depot_logo_state.dart';

class DepotHoldingAvatar extends StatelessWidget {
  final String name;
  final String colorSeed;
  final double size;
  final Uint8List? logoBytes;

  const DepotHoldingAvatar({
    super.key,
    required this.name,
    required this.colorSeed,
    this.size = 36,
    this.logoBytes,
  });

  static String initials(String name) {
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
    final cached = context.select<DepotLogoState, Uint8List?>(
      (state) => state.bytesFor(colorSeed),
    );
    final bytes = logoBytes ?? cached;
    final fallback = _InitialsBadge(
      name: name,
      colorSeed: colorSeed,
      size: size,
    );
    if (bytes == null) return fallback;
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(size / 4),
      ),
      child: Image.memory(
        bytes,
        fit: BoxFit.cover,
        cacheWidth: 96,
        excludeFromSemantics: true,
        errorBuilder: (context, error, stackTrace) => fallback,
      ),
    );
  }
}

class _InitialsBadge extends StatelessWidget {
  final String name;
  final String colorSeed;
  final double size;

  const _InitialsBadge({
    required this.name,
    required this.colorSeed,
    required this.size,
  });

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
        DepotHoldingAvatar.initials(name),
        style: TextStyle(
          color: color,
          fontSize: size * 0.375,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
