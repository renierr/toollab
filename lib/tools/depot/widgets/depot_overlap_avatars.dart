import 'package:flutter/material.dart';

import '../models/depot_holding.dart';
import 'depot_holding_avatar.dart';

/// Two fund avatars, the second tucked under the first's corner.
class DepotOverlapAvatars extends StatelessWidget {
  final DepotHolding first;
  final DepotHolding second;
  final double size;

  const DepotOverlapAvatars({
    super.key,
    required this.first,
    required this.second,
    this.size = 26,
  });

  static double widthOf(double size) => size * 1.6;

  @override
  Widget build(BuildContext context) {
    final ring = Theme.of(context).colorScheme.surface;
    return SizedBox(
      width: widthOf(size),
      height: size * 1.35,
      child: Stack(
        children: [
          DepotHoldingAvatar(
            name: first.name,
            colorSeed: first.identifier ?? first.id,
            size: size,
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(1.5),
              decoration: BoxDecoration(
                color: ring,
                borderRadius: BorderRadius.circular(size / 4 + 1.5),
              ),
              child: DepotHoldingAvatar(
                name: second.name,
                colorSeed: second.identifier ?? second.id,
                size: size,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
