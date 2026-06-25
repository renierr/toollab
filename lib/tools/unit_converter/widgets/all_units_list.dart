import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../unit_converter_state.dart';
import '../unit_format.dart';

/// Shows the current input converted into every unit of the active category.
/// Tapping a row selects it as the target ("to") unit.
class AllUnitsList extends StatelessWidget {
  final Color accent;

  const AllUnitsList({super.key, required this.accent});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final state = context.watch<UnitConverterState>();
    final conversions = state.allConversions;
    final units = state.category.units;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Text(
              l10n.ucAllUnits,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Divider(height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: units.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final unit = units[index];
              final isTo = unit.id == state.toUnit.id;
              final isFrom = unit.id == state.fromUnit.id;
              final value = conversions[unit.id];
              final valueText = value == null ? '—' : formatUnitValue(value);

              return InkWell(
                onTap: () => context.read<UnitConverterState>().setTo(unit),
                child: Container(
                  color: isTo
                      ? accent.withValues(alpha: 0.10)
                      : Colors.transparent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 56,
                        child: Text(
                          unit.symbol,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: isTo ? accent : theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          unit.name(l10n),
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withAlpha(180),
                          ),
                        ),
                      ),
                      if (isFrom)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Icon(
                            Icons.trip_origin,
                            size: 14,
                            color: theme.colorScheme.onSurface.withAlpha(120),
                          ),
                        ),
                      Flexible(
                        child: Text(
                          valueText,
                          textAlign: TextAlign.end,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            color: isTo ? accent : theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
