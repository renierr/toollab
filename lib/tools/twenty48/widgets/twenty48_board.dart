import 'package:flutter/material.dart';

import '../engine/twenty48_engine.dart';
import '../twenty48_colors.dart';
import 'twenty48_tile_view.dart';

/// The 4×4 grid and the tiles on it.
///
/// Square at any size and laid out from one measurement, so a phone and a
/// maximized desktop window play the identical board and only the scale
/// differs. Tiles are positioned by cell rather than laid out in rows: a
/// keyed `AnimatedPositioned` per tile is what makes a slide an implicit
/// animation, with no per-frame work and no ticker.
class Twenty48Board extends StatelessWidget {
  final Twenty48Engine engine;

  const Twenty48Board({super.key, required this.engine});

  static const Duration _slide = Duration(milliseconds: 110);

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const n = Twenty48Grid.size;
          final extent = constraints.biggest.shortestSide;
          final gap = extent * 0.022;
          final cell = (extent - gap * (n + 1)) / n;
          double at(int index) => gap + index * (cell + gap);

          return DecoratedBox(
            decoration: BoxDecoration(
              color: Twenty48Colors.board,
              borderRadius: BorderRadius.circular(extent * 0.04),
            ),
            child: Stack(
              children: [
                for (var row = 0; row < n; row++)
                  for (var col = 0; col < n; col++)
                    Positioned(
                      left: at(col),
                      top: at(row),
                      width: cell,
                      height: cell,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Twenty48Colors.emptyCell,
                          borderRadius: BorderRadius.circular(cell * 0.16),
                        ),
                      ),
                    ),
                for (final tile in engine.tiles)
                  AnimatedPositioned(
                    key: ValueKey(tile.id),
                    duration: _slide,
                    curve: Curves.easeOut,
                    left: at(tile.col),
                    top: at(tile.row),
                    width: cell,
                    height: cell,
                    child: Twenty48TileView(tile: tile, size: cell),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
