import 'package:flutter/material.dart';
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
    final options = [
      {'value': '1', 'label': '1 hr'},
      {'value': '8', 'label': '8 hrs'},
      {'value': '24', 'label': '24 hrs'},
      {'value': '168', 'label': '7 days'},
      {'value': 'indefinite', 'label': 'Indefinite'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Retention Period',
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
            final isSelected = selectedValue == opt['value'];
            return ChoiceChip(
              label: Text(
                opt['label']!,
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
                  onChanged(opt['value']!);
                }
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}
