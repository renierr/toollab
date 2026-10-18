import 'package:flutter/material.dart';

import 'package:tool_lab/l10n/app_localizations.dart';

import '../engine/sudoku_engine.dart';
import '../sudoku_colors.dart';

class SudokuNumpad extends StatelessWidget {
  final SudokuEngine engine;
  final bool notesMode;
  final int hintsRemaining;
  final bool canUndo;
  final ValueChanged<int> onNumber;
  final VoidCallback onErase;
  final VoidCallback onToggleNotes;
  final VoidCallback onHint;
  final VoidCallback onUndo;
  final VoidCallback onAutoNotes;
  final VoidCallback onClearNotes;

  const SudokuNumpad({
    super.key,
    required this.engine,
    required this.notesMode,
    required this.hintsRemaining,
    required this.canUndo,
    required this.onNumber,
    required this.onErase,
    required this.onToggleNotes,
    required this.onHint,
    required this.onUndo,
    required this.onAutoNotes,
    required this.onClearNotes,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final remaining = List<int>.filled(10, 0);
    for (int d = 1; d <= 9; d++) {
      int placed = 0;
      for (int i = 0; i < 81; i++) {
        if (engine.grid[i] == d) placed++;
      }
      remaining[d] = 9 - placed;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 4,
          runSpacing: 4,
          alignment: WrapAlignment.center,
          children: [
            for (int d = 1; d <= 9; d++)
              _NumButton(
                digit: d,
                remaining: remaining[d],
                onTap: remaining[d] == 0 ? null : () => onNumber(d),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: [
            _ActionChip(
              icon: notesMode ? Icons.edit : Icons.edit_outlined,
              label: notesMode ? l10n.sudokuNotesOn : l10n.sudokuNotesOff,
              active: notesMode,
              onTap: onToggleNotes,
            ),
            _ActionChip(
              icon: Icons.lightbulb_outline,
              label: hintsRemaining >= 999 ? '∞' : '$hintsRemaining',
              active: false,
              onTap: onHint,
            ),
            _ActionChip(
              icon: Icons.backspace_outlined,
              label: l10n.sudokuErase,
              active: false,
              onTap: onErase,
            ),
            _ActionChip(
              icon: Icons.undo,
              label: l10n.sudokuUndo,
              active: false,
              onTap: canUndo ? onUndo : null,
            ),
            _ActionChip(
              icon: Icons.auto_fix_high,
              label: l10n.sudokuAutoNotes,
              active: false,
              onTap: onAutoNotes,
            ),
            _ActionChip(
              icon: Icons.cleaning_services_outlined,
              label: l10n.sudokuClearNotes,
              active: false,
              onTap: onClearNotes,
            ),
          ],
        ),
      ],
    );
  }
}

class _NumButton extends StatelessWidget {
  final int digit;
  final int remaining;
  final VoidCallback? onTap;
  const _NumButton({required this.digit, required this.remaining, this.onTap});

  @override
  Widget build(BuildContext context) {
    final disabled = remaining == 0;
    return SizedBox(
      width: 48,
      height: 56,
      child: Material(
        color: disabled ? SudokuColors.numpadDisabled : SudokuColors.numpad,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$digit',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: disabled
                      ? SudokuColors.note.withValues(alpha: 0.4)
                      : SudokuColors.given,
                ),
              ),
              Text(
                '$remaining',
                style: TextStyle(
                  fontSize: 9,
                  color: disabled
                      ? SudokuColors.note.withValues(alpha: 0.3)
                      : SudokuColors.note,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.active,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active
          ? SudokuColors.selected.withValues(alpha: 0.3)
          : SudokuColors.numpad,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: onTap == null
                    ? SudokuColors.note.withValues(alpha: 0.4)
                    : SudokuColors.given,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: onTap == null
                      ? SudokuColors.note.withValues(alpha: 0.4)
                      : SudokuColors.given,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
