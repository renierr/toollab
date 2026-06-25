import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../models/unit_model.dart';

/// A labeled dropdown for picking a [UnitDef] from a category's unit list.
class UnitDropdown extends StatelessWidget {
  final String label;
  final List<UnitDef> units;
  final UnitDef value;
  final ValueChanged<UnitDef> onChanged;

  const UnitDropdown({
    super.key,
    required this.label,
    required this.units,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return DropdownButtonFormField<UnitDef>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      items: units.map((unit) {
        return DropdownMenuItem<UnitDef>(
          value: unit,
          child: Row(
            children: [
              Container(
                constraints: const BoxConstraints(minWidth: 44),
                child: Text(
                  unit.symbol,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  unit.name(l10n),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withAlpha(180),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
      onChanged: (unit) {
        if (unit != null) onChanged(unit);
      },
    );
  }
}
