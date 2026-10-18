import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:tool_lab/l10n/app_localizations.dart';

import '../sudoku_colors.dart';
import '../sudoku_state.dart';

class SudokuSettingsSheet {
  static Future<void> show(BuildContext context) async {
    final state = context.read<SudokuState>();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: SudokuColors.board,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _Sheet(state: state),
    );
  }
}

class _Sheet extends StatefulWidget {
  final SudokuState state;
  const _Sheet({required this.state});

  @override
  State<_Sheet> createState() => _SheetState();
}

class _SheetState extends State<_Sheet> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = widget.state;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Text(
            l10n.sudokuSettingsTitle,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: SudokuColors.given,
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            value: s.soundEnabled,
            onChanged: (v) => setState(() => s.setSoundEnabled(v)),
            title: Text(
              l10n.sudokuSound,
              style: const TextStyle(color: SudokuColors.given),
            ),
            subtitle: Text(
              l10n.sudokuSoundSubtitle,
              style: const TextStyle(color: SudokuColors.note),
            ),
          ),
          SwitchListTile(
            value: s.hapticsEnabled,
            onChanged: (v) => setState(() => s.setHapticsEnabled(v)),
            title: Text(
              l10n.sudokuHaptics,
              style: const TextStyle(color: SudokuColors.given),
            ),
            subtitle: Text(
              l10n.sudokuHapticsSubtitle,
              style: const TextStyle(color: SudokuColors.note),
            ),
          ),
          SwitchListTile(
            value: s.autoCheck,
            onChanged: (v) => setState(() => s.setAutoCheck(v)),
            title: Text(
              l10n.sudokuAutoCheck,
              style: const TextStyle(color: SudokuColors.given),
            ),
          ),
          SwitchListTile(
            value: s.highlightConflicts,
            onChanged: (v) => setState(() => s.setHighlightConflicts(v)),
            title: Text(
              l10n.sudokuHighlightConflicts,
              style: const TextStyle(color: SudokuColors.given),
            ),
          ),
          SwitchListTile(
            value: s.highlightSameNumber,
            onChanged: (v) => setState(() => s.setHighlightSameNumber(v)),
            title: Text(
              l10n.sudokuHighlightSameNumber,
              style: const TextStyle(color: SudokuColors.given),
            ),
          ),
          SwitchListTile(
            value: s.showTimer,
            onChanged: (v) => setState(() => s.setShowTimer(v)),
            title: Text(
              l10n.sudokuShowTimer,
              style: const TextStyle(color: SudokuColors.given),
            ),
          ),
          // Mistakes are unlimited (casual mode).
          // Hints are unlimited.
        ],
      ),
      ),
    );
  }
}
