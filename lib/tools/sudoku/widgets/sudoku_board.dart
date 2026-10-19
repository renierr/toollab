import 'package:flutter/material.dart';

import '../engine/sudoku_engine.dart';
import '../engine/sudoku_solver.dart';
import '../sudoku_colors.dart';
import 'sudoku_cell.dart';

class SudokuBoard extends StatelessWidget {
  static const double _boxLineWidth = 2;

  final SudokuEngine engine;
  final bool highlightConflicts;
  final bool highlightSameNumber;
  final bool autoCheck;
  final ValueChanged<int> onCellTap;

  const SudokuBoard({
    super.key,
    required this.engine,
    required this.highlightConflicts,
    required this.highlightSameNumber,
    required this.autoCheck,
    required this.onCellTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = SudokuColors.of(context);
    final grid = engine.grid;
    final given = engine.given;
    final notes = engine.notes;
    final selected = engine.selected;
    final selectedValue = selected >= 0 ? grid[selected] : 0;
    final conflicts = highlightConflicts
        ? engine.conflicts(includeWrong: autoCheck)
        : const <int>{};

    bool isPeer(int idx) =>
        selected >= 0 &&
        idx != selected &&
        (SudokuSolver.rowOf(selected) == SudokuSolver.rowOf(idx) ||
            SudokuSolver.colOf(selected) == SudokuSolver.colOf(idx) ||
            SudokuSolver.boxOf(selected) == SudokuSolver.boxOf(idx));

    Widget cell(int idx, double size) => SudokuCell(
      value: grid[idx],
      given: given[idx],
      notes: notes[idx],
      selected: selected == idx,
      peer: isPeer(idx),
      sameNumber:
          highlightSameNumber &&
          selectedValue != 0 &&
          idx != selected &&
          grid[idx] == selectedValue,
      conflict: conflicts.contains(idx),
      size: size,
      lineRight: SudokuSolver.colOf(idx) < 8,
      lineBottom: SudokuSolver.rowOf(idx) < 8,
      onTap: () => onCellTap(idx),
    );

    return AspectRatio(
      aspectRatio: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.board,
          border: Border.all(color: colors.boxLine, width: _boxLineWidth),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cellSize = constraints.maxWidth / 9;
            return Stack(
              children: [
                Column(
                  children: [
                    for (int row = 0; row < 9; row++)
                      Expanded(
                        child: Row(
                          children: [
                            for (int col = 0; col < 9; col++)
                              Expanded(child: cell(row * 9 + col, cellSize)),
                          ],
                        ),
                      ),
                  ],
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _BoxLinesPainter(
                        color: colors.boxLine,
                        width: _boxLineWidth,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BoxLinesPainter extends CustomPainter {
  final Color color;
  final double width;

  const _BoxLinesPainter({required this.color, required this.width});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = width;
    for (int i = 1; i < 3; i++) {
      final x = size.width * i / 3;
      final y = size.height * i / 3;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_BoxLinesPainter old) =>
      old.color != color || old.width != width;
}
