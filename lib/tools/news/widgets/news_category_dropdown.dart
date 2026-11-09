import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../news_catalog.dart';
import '../news_l10n.dart';

class NewsCategoryDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const NewsCategoryDropdown({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: l10n.newsSourceCategory,
        border: const OutlineInputBorder(),
      ),
      items: [
        for (final category in NewsCatalog.categories)
          DropdownMenuItem(
            value: category.id,
            child: Text(newsCategoryLabel(l10n, category.id)),
          ),
      ],
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }
}
