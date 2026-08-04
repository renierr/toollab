import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

/// Capped preview of the entries a dialog is about to act on, with an
/// "and N more" tail once the list gets long.
class FileManagerEntryNameList extends StatelessWidget {
  static const int limit = 3;

  final List<String> labels;

  const FileManagerEntryNameList({super.key, required this.labels});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...labels
            .take(limit)
            .map(
              (label) => Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ),
        if (labels.length > limit)
          Text(
            l10n.fileManagerMoreEntries(labels.length - limit),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}
