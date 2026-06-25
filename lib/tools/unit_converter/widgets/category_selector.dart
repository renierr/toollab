import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../unit_catalog.dart';
import '../unit_converter_state.dart';

/// Horizontally scrollable row of category chips.
class CategorySelector extends StatelessWidget {
  final Color accent;

  const CategorySelector({super.key, required this.accent});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final state = context.watch<UnitConverterState>();
    final selectedId = state.category.id;

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: UnitCatalog.categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = UnitCatalog.categories[index];
          final selected = category.id == selectedId;
          return _CategoryChip(
            icon: category.icon,
            label: category.name(l10n),
            selected: selected,
            accent: accent,
            onTap: () =>
                context.read<UnitConverterState>().selectCategory(category.id),
            theme: theme,
          );
        },
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;
  final ThemeData theme;

  const _CategoryChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected ? accent : theme.colorScheme.onSurface.withAlpha(170);
    return Material(
      color: selected ? accent.withValues(alpha: 0.16) : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? accent.withValues(alpha: 0.5)
                  : theme.dividerColor.withValues(alpha: 0.6),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
