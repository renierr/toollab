import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../depot_labels.dart';
import '../models/depot_activity.dart';

class DepotStatementHeader extends StatelessWidget {
  final ParsedStatement statement;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onRemove;
  final VoidCallback onShowText;

  const DepotStatementHeader({
    super.key,
    required this.statement,
    required this.onToggle,
    required this.onEdit,
    required this.onRemove,
    required this.onShowText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Row(
      children: [
        Checkbox(
          value: statement.selected && statement.isExportable,
          onChanged: statement.isExportable ? (_) => onToggle() : null,
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                statement.fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                DepotLabels.bank(l10n, statement.bank),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.text_snippet_outlined, size: 20),
          tooltip: l10n.depotImportRawTextTooltip,
          onPressed: onShowText,
        ),
        IconButton(
          icon: const Icon(Icons.edit_outlined, size: 20),
          tooltip: l10n.depotImportEditTooltip,
          onPressed: statement.activity == null ? null : onEdit,
        ),
        IconButton(
          icon: const Icon(Icons.close, size: 20),
          tooltip: l10n.depotImportRemoveTooltip,
          onPressed: onRemove,
        ),
      ],
    );
  }
}
