import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../engine/luma_well_engine.dart';
import '../luma_well_colors.dart';

class LumaWellPowerSheet extends StatelessWidget {
  const LumaWellPowerSheet({super.key});

  static Future<LumaWellPower?> show(BuildContext context) =>
      showModalBottomSheet<LumaWellPower>(
        context: context,
        isScrollControlled: true,
        builder: (_) => const LumaWellPowerSheet(),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final entries = [
      (
        LumaWellPower.pulse,
        Icons.bubble_chart_outlined,
        l10n.lumaWellPulse,
        l10n.lumaWellPulseSubtitle,
      ),
      (
        LumaWellPower.stabilize,
        Icons.pause_circle_outline,
        l10n.lumaWellStabilize,
        l10n.lumaWellStabilizeSubtitle,
      ),
      (
        LumaWellPower.brightenNext,
        Icons.wb_sunny_outlined,
        l10n.lumaWellGrow,
        l10n.lumaWellGrowSubtitle,
      ),
    ];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              l10n.lumaWellPowerMenu,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            for (final entry in entries)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(
                    entry.$2,
                    color: LumaWellColors.forLevel(entries.indexOf(entry) + 2),
                  ),
                  title: Text(entry.$3),
                  subtitle: Text(entry.$4),
                  onTap: () => Navigator.of(context).pop(entry.$1),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
