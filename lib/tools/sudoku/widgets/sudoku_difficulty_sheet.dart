import 'package:flutter/material.dart';

import 'package:tool_lab/l10n/app_localizations.dart';

import '../engine/sudoku_generator.dart';
import '../sudoku_colors.dart';

class SudokuDifficultySheet {
  static Future<SudokuDifficulty?> show(
    BuildContext context, {
    SudokuDifficulty? current,
  }) async {
    final l10n = AppLocalizations.of(context);
    return showModalBottomSheet<SudokuDifficulty>(
      context: context,
      backgroundColor: SudokuColors.board,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.sudokuSelectDifficulty,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: SudokuColors.given,
              ),
            ),
            const SizedBox(height: 12),
            for (final d in SudokuDifficulty.values)
              ListTile(
                title: Text(
                  _label(d, l10n),
                  style: const TextStyle(color: SudokuColors.given),
                ),
                trailing: current == d
                    ? const Icon(Icons.check, color: SudokuColors.success)
                    : null,
                onTap: () => Navigator.of(ctx).pop(d),
              ),
          ],
        ),
      ),
    );
  }

  static String _label(SudokuDifficulty d, AppLocalizations l10n) {
    switch (d) {
      case SudokuDifficulty.easy:
        return l10n.sudokuDifficultyEasy;
      case SudokuDifficulty.medium:
        return l10n.sudokuDifficultyMedium;
      case SudokuDifficulty.hard:
        return l10n.sudokuDifficultyHard;
      case SudokuDifficulty.expert:
        return l10n.sudokuDifficultyExpert;
    }
  }
}
