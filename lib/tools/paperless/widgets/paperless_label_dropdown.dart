import 'package:flutter/material.dart';

import '../models/paperless_label.dart';

/// Single choice among correspondents or document types; null means "any".
class PaperlessLabelDropdown extends StatelessWidget {
  final String label;
  final String noneLabel;
  final IconData icon;
  final List<PaperlessLabel> options;
  final int? value;
  final ValueChanged<int?> onChanged;

  const PaperlessLabelDropdown({
    super.key,
    required this.label,
    required this.noneLabel,
    required this.icon,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // A value the server no longer knows would trip the dropdown's assertion.
    final known = options.any((o) => o.id == value) ? value : null;
    return DropdownButtonFormField<int?>(
      key: ValueKey(known),
      initialValue: known,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      items: [
        DropdownMenuItem<int?>(value: null, child: Text(noneLabel)),
        for (final option in options)
          DropdownMenuItem<int?>(
            value: option.id,
            child: Text(option.name, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: onChanged,
    );
  }
}
