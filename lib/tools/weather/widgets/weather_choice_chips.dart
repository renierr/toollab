import 'package:material_ui/material_ui.dart';

/// A labelled row of choice chips for one setting.
class WeatherChoiceChips<T> extends StatelessWidget {
  const WeatherChoiceChips({
    super.key,
    this.label,
    required this.values,
    required this.selected,
    required this.text,
    required this.onChanged,
  });

  final String? label;
  final List<T> values;
  final T selected;
  final String Function(T value) text;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null) ...[
            Text(label!, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 6),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final v in values)
                ChoiceChip(
                  label: Text(text(v)),
                  selected: v == selected,
                  onSelected: (_) => onChanged(v),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
