import 'package:flutter/material.dart';

import 'package:tool_lab/l10n/app_localizations.dart';

import '../sudoku_colors.dart';

class SudokuNumpad extends StatelessWidget {
  /// Digits still to place, indexed 1–9; a digit at 0 is disabled.
  final List<int> remaining;
  final bool notesMode;
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
    required this.remaining,
    required this.notesMode,
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
              label: l10n.sudokuHint,
              onTap: onHint,
            ),
            _ActionChip(
              icon: Icons.backspace_outlined,
              label: l10n.sudokuErase,
              onTap: onErase,
            ),
            _ActionChip(
              icon: Icons.undo,
              label: l10n.sudokuUndo,
              onTap: canUndo ? onUndo : null,
            ),
            _ActionChip(
              icon: Icons.auto_fix_high,
              label: l10n.sudokuAutoNotes,
              onTap: onAutoNotes,
            ),
            _ActionChip(
              icon: Icons.cleaning_services_outlined,
              label: l10n.sudokuClearNotes,
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
  final VoidCallback? onTap;
  const _NumButton({required this.digit, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = SudokuColors.of(context);
    final disabled = onTap == null;
    return SizedBox(
      width: 48,
      height: 56,
      child: Material(
        color: disabled ? colors.numpadDisabled : colors.numpad,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Center(
            child: Text(
              '$digit',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: disabled
                    ? colors.note.withValues(alpha: 0.4)
                    : colors.given,
              ),
            ),
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
    this.active = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = SudokuColors.of(context);
    final fg = onTap == null
        ? colors.note.withValues(alpha: 0.4)
        : colors.given;
    return Material(
      color: active ? colors.selected.withValues(alpha: 0.3) : colors.numpad,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(fontSize: 12, color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}
