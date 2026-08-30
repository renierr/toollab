import 'package:flutter/material.dart';

import '../engine/twenty48_engine.dart';
import '../twenty48_colors.dart';

/// One numbered tile.
///
/// Sliding is not animated here — the board's `AnimatedPositioned` owns that.
/// What this adds is the two motions a slide cannot express: a tile that has
/// just appeared scales up from nothing, and one that has just swallowed
/// another overshoots and settles. Without them a merge is indistinguishable
/// from a number quietly changing.
class Twenty48TileView extends StatelessWidget {
  final Twenty48Tile tile;
  final double size;

  const Twenty48TileView({super.key, required this.tile, required this.size});

  @override
  Widget build(BuildContext context) {
    final color = Twenty48Colors.forValue(tile.value);
    final digits = '${tile.value}'.length;

    Widget body = DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size * 0.16),
        boxShadow: Twenty48Colors.glows(tile.value)
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.55),
                  blurRadius: size * 0.28,
                  spreadRadius: size * 0.02,
                ),
              ]
            : null,
      ),
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: size * 0.08),
          child: FittedBox(
            child: Text(
              '${tile.value}',
              maxLines: 1,
              style: TextStyle(
                // Four digits in the same box as one would be unreadable, so
                // the size steps down as the number grows; FittedBox catches
                // whatever is left past five digits.
                fontSize:
                    size * (digits <= 2 ? 0.44 : (digits == 3 ? 0.36 : 0.3)),
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ),
      ),
    );

    if (tile.spawned) {
      body = _Grow(key: ValueKey('spawn-${tile.id}'), child: body);
    } else if (tile.merged) {
      body = _Pop(key: ValueKey('pop-${tile.id}-${tile.value}'), child: body);
    }
    return SizedBox(width: size, height: size, child: body);
  }
}

/// Scales a newly dealt tile in from nothing.
class _Grow extends StatelessWidget {
  final Widget child;

  const _Grow({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.1, end: 1),
      duration: const Duration(milliseconds: 190),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: child,
    );
  }
}

/// Overshoots and settles, so a merge lands with weight.
///
/// Keyed on the tile's new value by the caller, which is what restarts the
/// animation on every merge rather than only the first.
class _Pop extends StatelessWidget {
  final Widget child;

  const _Pop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1.22, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: child,
    );
  }
}
