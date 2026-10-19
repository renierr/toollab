import 'package:tool_lab/l10n/app_localizations.dart';

import 'engine/sudoku_generator.dart';

extension SudokuDifficultyLabel on SudokuDifficulty {
  String label(AppLocalizations l10n) => switch (this) {
    SudokuDifficulty.easy => l10n.sudokuDifficultyEasy,
    SudokuDifficulty.medium => l10n.sudokuDifficultyMedium,
    SudokuDifficulty.hard => l10n.sudokuDifficultyHard,
    SudokuDifficulty.expert => l10n.sudokuDifficultyExpert,
  };
}

String formatSudokuTime(int seconds) {
  final m = (seconds ~/ 60).toString().padLeft(2, '0');
  final s = (seconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}
