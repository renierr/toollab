import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import '../chaindrop_colors.dart';
import '../engine/chaindrop_engine.dart';

/// The free, unlimited-use power-up menu — mirrors Ricochet's power menu, but
/// every entry here applies straight to the board instead of banking a shot
/// charge.
class ChainDropPowerMenuSheet extends StatelessWidget {
  const ChainDropPowerMenuSheet({super.key});

  /// Returns the chosen power, or null when the sheet was dismissed. The
  /// caller applies it, so the sheet never touches the engine.
  static Future<ChainDropPower?> show(BuildContext context) {
    return showModalBottomSheet<ChainDropPower>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const ChainDropPowerMenuSheet(),
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
                l10n.chaindropPowerMenu,
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
      power: ChainDropPower.clearColumn,
      title: l10n.chaindropPowerClearColumn,
      subtitle: l10n.chaindropPowerClearColumnDesc,
      icon: Icons.delete_sweep_outlined,
      color: ChainDropColors.best,
    ),
    _PowerEntry(
      power: ChainDropPower.defuse,
      title: l10n.chaindropPowerDefuse,
      subtitle: l10n.chaindropPowerDefuseDesc,
      icon: Icons.healing_outlined,
      color: ChainDropColors.forValue(5),
    ),
    _PowerEntry(
      power: ChainDropPower.reroll,
      title: l10n.chaindropPowerReroll,
      subtitle: l10n.chaindropPowerRerollDesc,
      icon: Icons.casino_outlined,
      color: ChainDropColors.score,
    ),
    _PowerEntry(
      power: ChainDropPower.wildDisc,
      title: l10n.chaindropPowerWildDisc,
      subtitle: l10n.chaindropPowerWildDiscDesc,
      icon: Icons.auto_fix_high,
      color: ChainDropColors.forValue(7),
    ),
  ];
}

class _PowerEntry {
  final ChainDropPower power;
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
