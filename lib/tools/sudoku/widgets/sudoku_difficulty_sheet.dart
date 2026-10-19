import 'package:flutter/material.dart';

import 'package:tool_lab/l10n/app_localizations.dart';

import '../engine/sudoku_generator.dart';
import '../sudoku_colors.dart';
import '../sudoku_labels.dart';

class SudokuDifficultySheet {
  SudokuDifficultySheet._();

  static Future<SudokuDifficulty?> show(
    BuildContext context, {
    SudokuDifficulty? current,
  }) {
    final l10n = AppLocalizations.of(context);
    final colors = SudokuColors.of(context);
    return showModalBottomSheet<SudokuDifficulty>(
      context: context,
      backgroundColor: colors.board,
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
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: colors.given,
              ),
            ),
            const SizedBox(height: 12),
            for (final d in SudokuDifficulty.values)
              ListTile(
                title: Text(
                  d.label(l10n),
                  style: TextStyle(color: colors.given),
                ),
                trailing: current == d
                    ? Icon(Icons.check, color: colors.success)
                    : null,
                onTap: () => Navigator.of(ctx).pop(d),
              ),
          ],
        ),
      ),
    );
  }
}
