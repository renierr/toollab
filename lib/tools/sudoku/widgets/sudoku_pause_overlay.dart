import 'package:flutter/material.dart';

import 'package:tool_lab/l10n/app_localizations.dart';

import '../sudoku_colors.dart';

class SudokuPauseOverlay extends StatelessWidget {
  final VoidCallback onResume;
  const SudokuPauseOverlay({super.key, required this.onResume});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = SudokuColors.of(context);
    return Positioned.fill(
      child: GestureDetector(
        onTap: onResume,
        child: Container(
          color: colors.page.withValues(alpha: 0.85),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.pause_circle_filled, size: 64, color: colors.given),
              const SizedBox(height: 12),
              Text(
                l10n.sudokuPausedTitle,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: colors.given,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.sudokuTapToResume,
                style: TextStyle(color: colors.note),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
