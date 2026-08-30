import 'package:flutter/material.dart';

import 'package:tool_lab/l10n/app_localizations.dart';
import 'game_stat.dart';

/// One control button in a [GameHud].
class GameHudAction {
  final IconData icon;
  final String tooltip;

  /// A null callback disables the button, which is how a HUD shows a power that
  /// is out of charges without the icon disappearing and moving the others.
  final VoidCallback? onPressed;
  final Color? color;

  /// Small overlay label on the icon — a count or a multiplier. Information,
  /// not decoration; a plain name belongs in [tooltip].
  final String? badge;

  const GameHudAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
    this.badge,
  });
}

/// The readouts-plus-controls bar every game page wears.
///
/// A 2-line layout on compact/narrow displays (back + controls on top, stats below),
/// a 1-line row on wide desktop displays, and a column beside the board in split layout.
class GameHud extends StatelessWidget {
  final List<GameStat> stats;
  final List<GameHudAction> actions;
  final bool vertical;
  final bool showBackButton;
  final VoidCallback? onBack;

  const GameHud({
    super.key,
    required this.stats,
    required this.actions,
    required this.vertical,
    this.showBackButton = true,
    this.onBack,
  });

  /// Width below which the HUD splits into 2 lines rather than crowding a single row.
  static const double _compactWidth = 560;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final canPop = showBackButton && Navigator.of(context).canPop();
    final backButton = canPop
        ? IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: l10n.commonBack,
            visualDensity: VisualDensity.compact,
            iconSize: 22,
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            onPressed: onBack ?? () => Navigator.of(context).maybePop(),
          )
        : const SizedBox.shrink();

    final controls = _Controls(actions: actions, vertical: vertical);

    if (vertical) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (canPop)
              Align(alignment: Alignment.centerLeft, child: backButton),
            const SizedBox(height: 8),
            for (final stat in stats)
              Padding(padding: const EdgeInsets.only(bottom: 14), child: stat),
            const Spacer(),
            controls,
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < _compactWidth;

        if (isCompact) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(8, 2, 8, 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [if (canPop) backButton, const Spacer(), controls],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    for (final stat in stats)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: stat,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Row(
            children: [
              if (canPop) ...[backButton, const SizedBox(width: 8)],
              Expanded(
                child: Row(
                  children: [
                    for (final stat in stats)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: stat,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              controls,
            ],
          ),
        );
      },
    );
  }
}

class _Controls extends StatelessWidget {
  final List<GameHudAction> actions;
  final bool vertical;

  const _Controls({required this.actions, required this.vertical});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: vertical ? WrapAlignment.center : WrapAlignment.end,
      spacing: 2,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final action in actions)
          IconButton(
            icon: action.badge == null
                ? Icon(action.icon)
                : Badge(
                    label: Text(action.badge!),
                    backgroundColor: action.color,
                    child: Icon(action.icon),
                  ),
            color: action.color,
            tooltip: action.tooltip,
            onPressed: action.onPressed,
            iconSize: 22,
            padding: const EdgeInsets.all(6),
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
      ],
    );
  }
}
