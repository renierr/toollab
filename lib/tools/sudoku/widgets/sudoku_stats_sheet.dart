import 'package:flutter/material.dart';

import 'package:tool_lab/l10n/app_localizations.dart';

import '../engine/sudoku_generator.dart';
import '../engine/sudoku_stats.dart';
import '../sudoku_colors.dart';
import '../sudoku_labels.dart';

class SudokuStatsSheet {
  SudokuStatsSheet._();

  static Future<void> show(BuildContext context, SudokuStats stats) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: SudokuColors.of(context).board,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _StatsSheet(stats: stats),
    );
  }
}

class _StatsSheet extends StatelessWidget {
  final SudokuStats stats;
  const _StatsSheet({required this.stats});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = SudokuColors.of(context);
    final bestTimes = [
      for (final d in SudokuDifficulty.values)
        if (stats[d].bestTime != null) d,
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.sudokuStats,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: colors.given,
            ),
          ),
          const SizedBox(height: 12),
          for (final d in SudokuDifficulty.values)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    d.label(l10n),
                    style: TextStyle(
                      color: colors.given,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      _Stat(l10n.sudokuGamesPlayed, stats[d].played),
                      _Stat(l10n.sudokuGamesWon, stats[d].won),
                      _Stat(l10n.sudokuCurrentStreak, stats[d].streak),
                      _Stat(l10n.sudokuBestStreak, stats[d].bestStreak),
                    ],
                  ),
                ],
              ),
            ),
          if (bestTimes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '${l10n.sudokuBestTimes}:',
              style: TextStyle(color: colors.note, fontWeight: FontWeight.w600),
            ),
            for (final d in bestTimes)
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 2),
                child: Text(
                  '${d.label(l10n)}: ${formatSudokuTime(stats[d].bestTime!)}',
                  style: TextStyle(color: colors.given),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final int value;
  const _Stat(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final colors = SudokuColors.of(context);
    return Column(
      children: [
        Text(
          '$value',
          style: TextStyle(color: colors.given, fontWeight: FontWeight.w700),
        ),
        Text(label, style: TextStyle(color: colors.note, fontSize: 10)),
      ],
    );
  }
}
