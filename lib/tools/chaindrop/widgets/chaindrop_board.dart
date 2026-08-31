import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../chaindrop_colors.dart';
import '../engine/chaindrop_engine.dart';
import 'chaindrop_disc_view.dart';

/// The 7x7 well and the discs in it.
///
/// Row 0 is the bottom of the board, so drawing flips the row index. Discs
/// are positioned by cell with a keyed `AnimatedPositioned`, the same
/// technique 2048 uses: gravity and drops become implicit animations with no
/// ticker of their own.
class ChainDropBoard extends StatelessWidget {
  final ChainDropEngine engine;
  final ValueChanged<int> onColumnTap;

  const ChainDropBoard({
    super.key,
    required this.engine,
    required this.onColumnTap,
  });

  static const Duration _fall = Duration(milliseconds: 160);

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const cols = ChainDropGrid.columns;
          const rows = ChainDropGrid.rows;
          final extent = constraints.biggest.shortestSide;
          final gap = extent * 0.018;
          final cell = (extent - gap * (cols + 1)) / cols;
          double atX(int col) => gap + col * (cell + gap);
          double atY(int row) => gap + (rows - 1 - row) * (cell + gap);

          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [ChainDropColors.boardHighlight, ChainDropColors.board],
              ),
              borderRadius: BorderRadius.circular(extent * 0.04),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
                width: math.max(1, extent * 0.004),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.32),
                  blurRadius: extent * 0.09,
                  offset: Offset(0, extent * 0.035),
                ),
              ],
            ),
            child: Stack(
              children: [
                for (var row = 0; row < rows; row++)
                  for (var col = 0; col < cols; col++)
                    Positioned(
                      left: atX(col),
                      top: atY(row),
                      width: cell,
                      height: cell,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: ChainDropColors.emptyCell,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.035),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: cell * 0.08,
                              offset: Offset(0, cell * 0.025),
                            ),
                          ],
                        ),
                      ),
                    ),
                for (var col = 0; col < cols; col++)
                  Positioned(
                    left: atX(col),
                    top: 0,
                    width: cell,
                    height: extent,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap:
                          engine.isColumnFull(col) ||
                              engine.isResolving ||
                              engine.isGameOver
                          ? null
                          : () => onColumnTap(col),
                    ),
                  ),
                for (final disc in engine.discs)
                  AnimatedPositioned(
                    key: ValueKey(disc.id),
                    duration: _fall,
                    curve: Curves.easeIn,
                    left: atX(disc.col),
                    top: atY(disc.row),
                    width: cell,
                    height: cell,
                    child: ChainDropDiscView(disc: disc, size: cell),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
