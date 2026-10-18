import 'dart:math';

import 'sudoku_solver.dart';

enum SudokuDifficulty { easy, medium, hard, expert }

/// Generates a Sudoku puzzle (81-cell list, 0 = empty) plus its solution.
class SudokuGenerator {
  SudokuGenerator._();

  static const _clueTargets = {
    SudokuDifficulty.easy: 46,
    SudokuDifficulty.medium: 36,
    SudokuDifficulty.hard: 29,
    SudokuDifficulty.expert: 23,
  };

  /// Returns (puzzle, solution).
  static (List<int>, List<int>) generate(
    SudokuDifficulty difficulty, {
    Random? random,
  }) {
    final rng = random ?? Random();
    final solution = _generateComplete(rng);
    final puzzle = List<int>.from(solution);

    final targetClues = _clueTargets[difficulty]!;
    final targetRemove = 81 - targetClues;

    // Candidate cells to remove, shuffled.
    final indices = List<int>.generate(81, (i) => i)..shuffle(rng);

    int removed = 0;
    for (final idx in indices) {
      if (removed >= targetRemove) break;
      final backup = puzzle[idx];
      puzzle[idx] = 0;
      // Ensure unique solution.
      if (SudokuSolver.countSolutions(puzzle, limit: 2) != 1) {
        puzzle[idx] = backup;
      } else {
        removed++;
      }
    }
    return (puzzle, solution);
  }

  static List<int> _generateComplete(Random rng) {
    final grid = List<int>.filled(81, 0);
    // Fill diagonal 3x3 boxes first (independent).
    for (int b = 0; b < 3; b++) {
      final vals = List<int>.generate(9, (i) => i + 1)..shuffle(rng);
      int k = 0;
      for (int dr = 0; dr < 3; dr++) {
        for (int dc = 0; dc < 3; dc++) {
          grid[(b * 3 + dr) * 9 + (b * 3 + dc)] = vals[k++];
        }
      }
    }
    // Solve the rest with randomized candidate order.
    _solveRandom(grid, rng);
    return grid;
  }

  static bool _solveRandom(List<int> grid, Random rng) {
    final idx = _firstEmpty(grid);
    if (idx == -1) return true;
    final cands = SudokuSolver.candidates(grid, idx).toList()..shuffle(rng);
    for (final v in cands) {
      grid[idx] = v;
      if (_solveRandom(grid, rng)) return true;
    }
    grid[idx] = 0;
    return false;
  }

  static int _firstEmpty(List<int> grid) {
    for (int i = 0; i < grid.length; i++) {
      if (grid[i] == 0) return i;
    }
    return -1;
  }
}
