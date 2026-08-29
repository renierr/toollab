import 'package:flutter/material.dart';

import 'package:tool_lab/l10n/app_localizations.dart';
import '../engine/ricochet_engine.dart';
import '../ricochet_colors.dart';

/// The two in-volley controls, pinned to the bottom corners of the board.
///
/// Icon-only, with the name in a tooltip: they sit over the playfield, and a
/// pair of labelled pills there covers bricks and crowds the launcher on a
/// phone. Both dim to inert when no volley is in flight rather than
/// disappearing, so their position is learned once and never shifts mid-turn.
class RicochetActionBar extends StatelessWidget {
  final RicochetEngine engine;

  const RicochetActionBar({super.key, required this.engine});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AnimatedBuilder(
      animation: engine.hud,
      builder: (context, _) {
        final active = engine.volleyActive;
        final boosted = engine.speedMultiplier > 1;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _ActionButton(
                tooltip: l10n.ricochetRecall,
                icon: Icons.undo_rounded,
                enabled: active,
                color: RicochetColors.ballTrail,
                onPressed: engine.recallBalls,
              ),
              _ActionButton(
                // The multiplier is information, not a label, so it rides on
                // the icon as a badge while the tooltip names the control.
                tooltip: boosted
                    ? l10n.ricochetSpeedActive(engine.speedMultiplier)
                    : l10n.ricochetSpeed,
                icon: Icons.fast_forward_rounded,
                enabled:
                    active && engine.speedMultiplier < RicochetTuning.maxSpeed,
                highlighted: boosted,
                badge: boosted ? '×${engine.speedMultiplier}' : null,
                color: RicochetColors.bonus,
                onPressed: engine.boostSpeed,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final bool enabled;
  final bool highlighted;
  final String? badge;
  final Color color;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.tooltip,
    required this.icon,
    required this.enabled,
    required this.color,
    required this.onPressed,
    this.highlighted = false,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final tint = highlighted ? color : Colors.white;
    final glyph = Icon(icon, size: 22, color: tint);
    return AnimatedOpacity(
      opacity: enabled || highlighted ? 1 : 0.32,
      duration: const Duration(milliseconds: 180),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: RicochetColors.board.withValues(alpha: 0.82),
          shape: CircleBorder(
            side: BorderSide(color: tint.withValues(alpha: 0.35)),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: enabled ? onPressed : null,
            child: Padding(
              padding: const EdgeInsets.all(9),
              child: badge == null
                  ? glyph
                  : Badge(
                      label: Text(badge!),
                      backgroundColor: color,
                      textColor: RicochetColors.board,
                      child: glyph,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
