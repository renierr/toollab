import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';

class RetentionSelector extends StatelessWidget {
  final String selectedValue;
  final ValueChanged<String> onChanged;

  const RetentionSelector({
    super.key,
    required this.selectedValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final options = [
      ('1', l10n.fastDropRetention1Hour),
      ('8', l10n.fastDropRetention8Hours),
      ('24', l10n.fastDropRetention24Hours),
      ('168', l10n.fastDropRetention7Days),
      ('indefinite', l10n.fastDropRetentionIndefinite),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.fastDropRetentionPeriod,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((opt) {
            final (value, label) = opt;
            final isSelected = selectedValue == value;
            return ChoiceChip(
              label: Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : theme.colorScheme.onSurface,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              selected: isSelected,
              selectedColor: AppTheme.accentTeal,
              backgroundColor: theme.colorScheme.surfaceContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: isSelected
                      ? Colors.transparent
                      : theme.colorScheme.outlineVariant,
                ),
              ),
              onSelected: (selected) {
                if (selected) {
                  onChanged(value);
                }
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}
