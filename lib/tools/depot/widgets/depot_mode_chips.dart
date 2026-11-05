import 'package:flutter/material.dart';

/// Small choice chips that switch what a depot card shows.
class DepotModeChips<T> extends StatelessWidget {
  final T selected;
  final List<(T, String)> options;
  final ValueChanged<T> onSelected;

  const DepotModeChips({
    super.key,
    required this.selected,
    required this.options,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall;
    return Wrap(
      spacing: 8,
      children: [
        for (final (value, label) in options)
          ChoiceChip(
            label: Text(label),
            labelStyle: style,
            labelPadding: const EdgeInsets.symmetric(horizontal: 6),
            padding: EdgeInsets.zero,
            showCheckmark: false,
            selected: selected == value,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onSelected: (_) => onSelected(value),
          ),
      ],
    );
  }
}
