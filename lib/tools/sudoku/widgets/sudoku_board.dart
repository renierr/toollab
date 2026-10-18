import 'package:flutter/material.dart';

import '../engine/sudoku_engine.dart';
import '../engine/sudoku_solver.dart';
import '../sudoku_colors.dart';
import 'sudoku_cell.dart';

class SudokuBoard extends StatelessWidget {
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
    final grid = engine.grid;
    final given = engine.given;
    final notes = engine.notes;
    final selected = engine.selected;
    final selectedValue = selected >= 0 ? grid[selected] : 0;

    // Precompute conflict set.
    final conflicts = <int>{};
    if (highlightConflicts) {
      for (int i = 0; i < 81; i++) {
        final v = grid[i];
        if (v == 0) continue;
        // check peers
        bool dup = false;
        // row
        final r = SudokuSolver.rowOf(i);
        final c = SudokuSolver.colOf(i);
        for (int k = 0; k < 9; k++) {
          final ri = r * 9 + k;
          final ci = k * 9 + c;
          if (ri != i && grid[ri] == v) dup = true;
          if (ci != i && grid[ci] == v) dup = true;
        }
        // box
        final br = (r ~/ 3) * 3;
        final bc = (c ~/ 3) * 3;
        for (int dr = 0; dr < 3; dr++) {
          for (int dc = 0; dc < 3; dc++) {
            final bi = (br + dr) * 9 + (bc + dc);
            if (bi != i && grid[bi] == v) dup = true;
          }
        }
        if (dup) conflicts.add(i);
        // auto-check wrong value
        if (autoCheck && v != engine.solution[i]) conflicts.add(i);
      }
    }

    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          color: SudokuColors.board,
          border: Border.all(color: SudokuColors.board, width: 2),
        ),
        child: Column(
          children: [
            for (int row = 0; row < 9; row++)
              Expanded(
                child: Row(
                  children: [
                    for (int col = 0; col < 9; col++) ...[
                      Expanded(
                        child: _buildCell(
                          row * 9 + col,
                          grid,
                          given,
                          notes,
                          selected,
                          selectedValue,
                          conflicts,
                          row,
                          col,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCell(
    int idx,
    List<int> grid,
    List<bool> given,
    List<Set<int>> notes,
    int selected,
    int selectedValue,
    Set<int> conflicts,
    int row,
    int col,
  ) {
    final isPeer =
        selected >= 0 &&
        (SudokuSolver.rowOf(selected) == row ||
            SudokuSolver.colOf(selected) == col ||
            SudokuSolver.boxOf(selected) == SudokuSolver.boxOf(idx));

    final isSame =
        highlightSameNumber && selectedValue != 0 && grid[idx] == selectedValue;

    final hinted = false;

    return SudokuCell(
      value: grid[idx],
      given: given[idx],
      notes: notes[idx],
      selected: selected == idx,
      peer: selected >= 0 && selected != idx && isPeer,
      sameNumber: isSame && selected != idx,
      conflict: conflicts.contains(idx),
      hinted: hinted,
      onTap: () => onCellTap(idx),
      thickRight: (col + 1) % 3 == 0 && col < 8,
      thickBottom: (row + 1) % 3 == 0 && row < 8,
    );
  }
}
