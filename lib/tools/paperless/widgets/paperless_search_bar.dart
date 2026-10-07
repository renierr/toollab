import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../models/paperless_filter.dart';
import '../paperless_sort_labels.dart';

class PaperlessSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final PaperlessSort sort;
  final ValueChanged<PaperlessSort> onSortChanged;
  final int activeFilters;
  final VoidCallback onOpenFilters;
  final int? resultCount;

  const PaperlessSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.sort,
    required this.onSortChanged,
    required this.activeFilters,
    required this.onOpenFilters,
    required this.resultCount,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  onChanged: onChanged,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: l10n.paperlessSearchHint,
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    suffixIcon: ListenableBuilder(
                      listenable: controller,
                      builder: (context, _) => controller.text.isEmpty
                          ? const SizedBox.shrink()
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              tooltip: l10n.commonClear,
                              onPressed: () {
                                controller.clear();
                                onChanged('');
                              },
                            ),
                    ),
                  ),
                ),
              ),
              PopupMenuButton<PaperlessSort>(
                icon: const Icon(Icons.sort),
                tooltip: l10n.paperlessSort,
                initialValue: sort,
                onSelected: onSortChanged,
                itemBuilder: (context) => [
                  for (final option in PaperlessSort.values)
                    CheckedPopupMenuItem(
                      value: option,
                      checked: option == sort,
                      child: Text(paperlessSortLabel(l10n, option)),
                    ),
                ],
              ),
              IconButton(
                tooltip: l10n.paperlessFilters,
                onPressed: onOpenFilters,
                icon: Badge(
                  isLabelVisible: activeFilters > 0,
                  label: Text('$activeFilters'),
                  child: const Icon(Icons.filter_list),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 0, 4),
            child: Text(
              [
                if (resultCount != null)
                  l10n.paperlessDocumentCount(resultCount!),
                paperlessSortLabel(l10n, sort),
              ].join(' · '),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
