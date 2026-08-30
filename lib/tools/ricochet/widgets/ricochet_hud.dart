import 'package:flutter/material.dart';

import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/game_hud.dart';
import 'package:tool_lab/widgets/game_stat.dart';
import '../engine/ricochet_engine.dart';
import '../ricochet_colors.dart';

/// Score, best, level and ball count, plus top-row controls.
class RicochetHud extends StatelessWidget {
  final RicochetEngine engine;
  final bool vertical;
  final VoidCallback onOpenPowers;
  final VoidCallback onRestartLevel;

  const RicochetHud({
    super.key,
    required this.engine,
    required this.vertical,
    required this.onOpenPowers,
    required this.onRestartLevel,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AnimatedBuilder(
      animation: engine.hud,
      builder: (context, _) => GameHud(
        vertical: vertical,
        stats: [
          GameStat(
            label: l10n.ricochetScore,
            value: '${engine.score}',
            centered: true,
          ),
          GameStat(
            label: l10n.ricochetBest,
            value: '${engine.best}',
            color: RicochetColors.bonus,
            centered: true,
          ),
          GameStat(
            label: l10n.ricochetLevel,
            value: '${engine.level}',
            centered: true,
          ),
          GameStat(
            label: l10n.ricochetBalls,
            value: '${engine.totalBalls}',
            color: RicochetColors.launcher,
            centered: true,
          ),
        ],
        actions: [
          GameHudAction(
            icon: Icons.refresh_rounded,
            tooltip: l10n.ricochetRestartLevel,
            onPressed: onRestartLevel,
          ),
          GameHudAction(
            icon: Icons.grid_view_rounded,
            tooltip: l10n.ricochetPowerMenu,
            onPressed: onOpenPowers,
          ),
        ],
      ),
    );
  }
}
