import 'package:flutter/material.dart';

import 'package:tool_lab/l10n/app_localizations.dart';

import '../engine/sudoku_engine.dart';
import '../sudoku_colors.dart';
import '../sudoku_labels.dart';

class SudokuHud extends StatelessWidget {
  final SudokuEngine engine;
  final bool showTimer;
  final VoidCallback onChangeDifficulty;
  final VoidCallback onTogglePause;
  final VoidCallback onNewGame;

  const SudokuHud({
    super.key,
    required this.engine,
    required this.showTimer,
    required this.onChangeDifficulty,
    required this.onTogglePause,
    required this.onNewGame,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = SudokuColors.of(context);
    // Right inset keeps clear of the fullscreen layout's floating actions.
    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 96, top: 6, bottom: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          InkWell(
            onTap: onChangeDifficulty,
            borderRadius: BorderRadius.circular(8),
            child: _HudChip(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    engine.difficulty.label(l10n),
                    style: TextStyle(
                      color: colors.given,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(Icons.arrow_drop_down, size: 16, color: colors.note),
                ],
              ),
            ),
          ),
          if (showTimer)
            ValueListenableBuilder<int>(
              valueListenable: engine.elapsedListenable,
              builder: (context, elapsed, _) => _InfoChip(
                icon: Icons.timer_outlined,
                label: formatSudokuTime(elapsed),
              ),
            ),
          _InfoChip(
            icon: Icons.close,
            label: '${engine.mistakes}',
            color: engine.mistakes > 0 ? colors.conflict : null,
          ),
          _HudIconButton(
            icon: engine.paused ? Icons.play_arrow : Icons.pause,
            tooltip: engine.paused ? l10n.sudokuResume : l10n.sudokuPause,
            onPressed: onTogglePause,
          ),
          _HudIconButton(
            icon: Icons.refresh,
            tooltip: l10n.sudokuNewGame,
            onPressed: onNewGame,
          ),
        ],
      ),
    );
  }
}

class _HudChip extends StatelessWidget {
  final Widget child;
  const _HudChip({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: SudokuColors.of(context).numpad,
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  const _InfoChip({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final colors = SudokuColors.of(context);
    return _HudChip(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color ?? colors.note),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color ?? colors.given,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _HudIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  const _HudIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon),
      color: SudokuColors.of(context).given,
      tooltip: tooltip,
      iconSize: 20,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      onPressed: onPressed,
    );
  }
}
