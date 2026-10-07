import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../models/paperless_label.dart';
import 'paperless_tag_chip.dart';

class PaperlessTagSelector extends StatelessWidget {
  final List<PaperlessLabel> tags;
  final Set<int> selected;
  final ValueChanged<Set<int>> onChanged;

  const PaperlessTagSelector({
    super.key,
    required this.tags,
    required this.selected,
    required this.onChanged,
  });

  void _toggle(int id) {
    final next = {...selected};
    if (!next.remove(id)) next.add(id);
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (tags.isEmpty) {
      return Text(
        AppLocalizations.of(context).paperlessNoTags,
        style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 220),
      child: SingleChildScrollView(
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final tag in tags)
              FilterChip(
                avatar: PaperlessTagDot(color: tag.color),
                label: Text(tag.name),
                selected: selected.contains(tag.id),
                onSelected: (_) => _toggle(tag.id),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ),
    );
  }
}
