import 'sudoku_generator.dart';

class SudokuDifficultyStats {
  int played = 0;
  int won = 0;
  int streak = 0;
  int bestStreak = 0;
  int? bestTime;
}

class SudokuStats {
  SudokuStats();

  final Map<SudokuDifficulty, SudokuDifficultyStats> _byDifficulty = {
    for (final d in SudokuDifficulty.values) d: SudokuDifficultyStats(),
  };

  SudokuDifficultyStats operator [](SudokuDifficulty d) => _byDifficulty[d]!;

  factory SudokuStats.fromJson(Map<String, dynamic> json) {
    int read(String field, SudokuDifficulty d) =>
        ((json[field] as Map?)?[d.name] as num?)?.toInt() ?? 0;

    final stats = SudokuStats();
    for (final d in SudokuDifficulty.values) {
      stats[d]
        ..played = read('played', d)
        ..won = read('won', d)
        ..streak = read('streak', d)
        ..bestStreak = read('bestStreak', d);
    }
    return stats;
  }

  // Best times are stored under their own keys, see SudokuStore.
  Map<String, dynamic> toJson() {
    Map<String, int> field(int Function(SudokuDifficultyStats) pick) => {
      for (final d in SudokuDifficulty.values) d.name: pick(this[d]),
    };
    return {
      'played': field((s) => s.played),
      'won': field((s) => s.won),
      'streak': field((s) => s.streak),
      'bestStreak': field((s) => s.bestStreak),
    };
  }
}
