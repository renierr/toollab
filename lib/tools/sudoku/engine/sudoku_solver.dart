/// Pure Sudoku solving helpers. Operates on a flat 81-cell list (0 = empty).
class SudokuSolver {
  SudokuSolver._();

  static const int size = 9;
  static const int boxSize = 3;

  static int rowOf(int i) => i ~/ size;
  static int colOf(int i) => i % size;
  static int boxOf(int i) =>
      (rowOf(i) ~/ boxSize) * boxSize + (colOf(i) ~/ boxSize);

  static bool isValidPlacement(List<int> grid, int index, int value) {
    if (value == 0) return true;
    final r = rowOf(index);
    final c = colOf(index);
    final b = boxOf(index);
    for (int i = 0; i < size; i++) {
      // row
      final ri = r * size + i;
      if (ri != index && grid[ri] == value) return false;
      // col
      final ci = i * size + c;
      if (ci != index && grid[ci] == value) return false;
    }
    // box
    final br = (b ~/ boxSize) * boxSize;
    final bc = (b % boxSize) * boxSize;
    for (int dr = 0; dr < boxSize; dr++) {
      for (int dc = 0; dc < boxSize; dc++) {
        final bi = (br + dr) * size + (bc + dc);
        if (bi != index && grid[bi] == value) return false;
      }
    }
    return true;
  }

  /// Returns all legal candidate values for [index] given [grid].
  static Set<int> candidates(List<int> grid, int index) {
    if (grid[index] != 0) return const {};
    final result = <int>{};
    for (int v = 1; v <= 9; v++) {
      if (isValidPlacement(grid, index, v)) result.add(v);
    }
    return result;
  }

  /// Counts solutions up to [limit] without mutating the input.
  static int countSolutions(List<int> grid, {int limit = 2}) {
    final copy = List<int>.from(grid);
    int count = 0;
    void rec() {
      if (count >= limit) return;
      final idx = _firstEmpty(copy);
      if (idx == -1) {
        count++;
        return;
      }
      final cands = candidates(copy, idx).toList()..sort();
      for (final v in cands) {
        if (count >= limit) return;
        copy[idx] = v;
        rec();
      }
      copy[idx] = 0;
    }

    rec();
    return count;
  }

  static int _firstEmpty(List<int> grid) {
    for (int i = 0; i < grid.length; i++) {
      if (grid[i] == 0) return i;
    }
    return -1;
  }
}
