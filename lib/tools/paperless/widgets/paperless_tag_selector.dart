import 'package:flutter/material.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../models/paperless_label.dart';
import 'paperless_tag_chip.dart';

class PaperlessTagSelector extends StatefulWidget {
  final List<PaperlessLabel> tags;
  final Set<int> selected;
  final ValueChanged<Set<int>> onChanged;

  const PaperlessTagSelector({
    super.key,
    required this.tags,
    required this.selected,
    required this.onChanged,
  });

  @override
  State<PaperlessTagSelector> createState() => _PaperlessTagSelectorState();
}

class _PaperlessTagSelectorState extends State<PaperlessTagSelector>
    with DisposeCleanup {
  static const _filterThreshold = 6;

  final _query = TextEditingController();

  @override
  void initState() {
    super.initState();
    onDispose(_query.dispose);
  }

  void _toggle(int id) {
    final next = {...widget.selected};
    if (!next.remove(id)) next.add(id);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final hintStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.hintColor,
    );
    if (widget.tags.isEmpty) {
      return Text(l10n.paperlessNoTags, style: hintStyle);
    }

    final showFilter = widget.tags.length > _filterThreshold;
    final query = _query.text.trim().toLowerCase();
    // Selected tags stay visible so they can still be deselected.
    final visible = query.isEmpty
        ? widget.tags
        : widget.tags
              .where(
                (tag) =>
                    widget.selected.contains(tag.id) ||
                    tag.name.toLowerCase().contains(query),
              )
              .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showFilter) ...[
          TextField(
            controller: _query,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: l10n.paperlessFilterTags,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: l10n.commonClear,
                      onPressed: () => setState(_query.clear),
                    ),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (visible.isEmpty)
          Text(l10n.paperlessNoMatchingTags, style: hintStyle)
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final tag in visible)
                    FilterChip(
                      avatar: PaperlessTagDot(color: tag.color),
                      label: Text(tag.name),
                      selected: widget.selected.contains(tag.id),
                      onSelected: (_) => _toggle(tag.id),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
