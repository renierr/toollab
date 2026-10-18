import 'package:flutter/material.dart';

import 'package:tool_lab/l10n/app_localizations.dart';

import '../engine/sudoku_engine.dart';
import '../engine/sudoku_generator.dart';
import '../sudoku_colors.dart';

class SudokuStatsSheet {
  static Future<void> show(BuildContext context, SudokuEngine engine) async {
    final l10n = AppLocalizations.of(context);
    final stats = engine.stats;
    final played = (stats['played'] as Map?) ?? {};
    final won = (stats['won'] as Map?) ?? {};
    final streak = (stats['streak'] as Map?) ?? {};
    final bestStreak = (stats['bestStreak'] as Map?) ?? {};

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: SudokuColors.board,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.sudokuStats,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: SudokuColors.given)),
              const SizedBox(height: 12),
              for (final d in SudokuDifficulty.values)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_label(d, l10n),
                          style: const TextStyle(color: SudokuColors.given, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          _stat(l10n.sudokuGamesPlayed, '${played[d.name] ?? 0}'),
                          _stat(l10n.sudokuGamesWon, '${won[d.name] ?? 0}'),
                          _stat(l10n.sudokuCurrentStreak, '${streak[d.name] ?? 0}'),
                          _stat(l10n.sudokuBestStreak, '${bestStreak[d.name] ?? 0}'),
                        ],
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                '${l10n.sudokuBestTimes}:',
                style: const TextStyle(color: SudokuColors.note, fontWeight: FontWeight.w600),
              ),
              for (final d in SudokuDifficulty.values)
                FutureBuilder<int?>(
                  future: engine.bestTime(d.name),
                  builder: (ctx, snap) {
                    final t = snap.data;
                    if (t == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(left: 8, top: 2),
                      child: Text(
                        '${_label(d, l10n)}: ${_fmt(t)}',
                        style: const TextStyle(color: SudokuColors.given),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _stat(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: SudokuColors.given, fontWeight: FontWeight.w700)),
        Text(label, style: const TextStyle(color: SudokuColors.note, fontSize: 10)),
      ],
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

  static String _fmt(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}