import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../news_source.dart';

class NewsSourceFilterBar extends StatelessWidget {
  final List<NewsSource> sources;
  final String? selectedSourceId;
  final Map<String, int> unreadCounts;
  final int totalUnread;
  final ValueChanged<String?> onSelected;

  const NewsSourceFilterBar({
    super.key,
    required this.sources,
    required this.selectedSourceId,
    required this.unreadCounts,
    required this.totalUnread,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (sources.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final enabled = sources.where((source) => source.enabled).toList();

    return SizedBox(
      height: 54,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        children: [
          _SourceChip(
            label: totalUnread > 0
                ? '${l10n.newsAllSources} · $totalUnread'
                : l10n.newsAllSources,
            selected: selectedSourceId == null,
            onTap: () => onSelected(null),
          ),
          for (final source in enabled)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _SourceChip(
                label: (unreadCounts[source.shortId] ?? 0) > 0
                    ? '${source.title} · ${unreadCounts[source.shortId]}'
                    : source.title,
                selected: selectedSourceId == source.shortId,
                warning: source.hasError,
                onTap: () => onSelected(source.shortId),
              ),
            ),
        ],
      ),
    );
  }
}

class _SourceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool warning;
  final VoidCallback onTap;

  const _SourceChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.warning = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => onTap(),
      visualDensity: VisualDensity.compact,
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (warning) ...[
            Icon(Icons.error_outline, size: 14, color: theme.colorScheme.error),
            const SizedBox(width: 4),
          ],
          Text(label),
        ],
      ),
      labelStyle: theme.textTheme.labelMedium?.copyWith(
        color: selected
            ? theme.colorScheme.onSecondaryContainer
            : theme.colorScheme.onSurfaceVariant,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      ),
    );
  }
}
