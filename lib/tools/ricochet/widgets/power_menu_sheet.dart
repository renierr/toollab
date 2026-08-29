import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import '../engine/ricochet_engine.dart';
import '../ricochet_colors.dart';

/// The unlimited-use power-up menu.
///
/// Every entry banks exactly the charge its matching tile does, so the menu and
/// the board share one vocabulary — whatever is banked shows as a chip above
/// the launcher until the volley spends it.
class PowerMenuSheet extends StatelessWidget {
  const PowerMenuSheet({super.key});

  /// Returns the chosen power, or null when the sheet was dismissed. The caller
  /// applies it, so the sheet never touches the engine.
  static Future<PowerUp?> show(BuildContext context) {
    return showModalBottomSheet<PowerUp>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const PowerMenuSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withAlpha(60),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                l10n.ricochetPowerMenu,
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              // Cards, not a fixed row: four side by side overflow a narrow
              // phone, and a wide window would stretch them into billboards.
              LayoutBuilder(
                builder: (context, constraints) => Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final entry in _entries(l10n))
                      SizedBox(
                        width: constraints.maxWidth >= 420
                            ? (constraints.maxWidth - 10) / 2
                            : constraints.maxWidth,
                        child: _PowerTile(entry: entry),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<_PowerEntry> _entries(AppLocalizations l10n) => [
    _PowerEntry(
      power: PowerUp.balls,
      title: l10n.ricochetPowerBalls,
      subtitle: l10n.ricochetPowerBallsDesc,
      icon: Icons.add_circle_outline,
      color: RicochetColors.launcher,
    ),
    _PowerEntry(
      power: PowerUp.pierce,
      title: l10n.ricochetPowerPierce,
      subtitle: l10n.ricochetPowerPierceDesc,
      icon: Icons.double_arrow_rounded,
      color: RicochetColors.pierceLight,
    ),
    _PowerEntry(
      power: PowerUp.bomb,
      title: l10n.ricochetPowerBomb,
      subtitle: l10n.ricochetPowerBombDesc,
      icon: Icons.auto_awesome,
      color: RicochetColors.blastLight,
    ),
    _PowerEntry(
      power: PowerUp.clearRow,
      title: l10n.ricochetPowerClearRow,
      subtitle: l10n.ricochetPowerClearRowDesc,
      icon: Icons.horizontal_rule_rounded,
      color: RicochetColors.pickup,
    ),
  ];
}

class _PowerEntry {
  final PowerUp power;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _PowerEntry({
    required this.power,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}

class _PowerTile extends StatelessWidget {
  final _PowerEntry entry;

  const _PowerTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).pop(entry.power),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: entry.color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(entry.icon, color: entry.color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      entry.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      entry.subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
