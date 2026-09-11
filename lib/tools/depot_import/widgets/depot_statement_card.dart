import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/status_badge.dart';

import '../depot_labels.dart';
import '../models/depot_activity.dart';
import 'depot_activity_fields.dart';
import 'depot_statement_header.dart';

class DepotStatementCard extends StatelessWidget {
  final ParsedStatement statement;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onRemove;
  final VoidCallback onShowText;

  const DepotStatementCard({
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
    final activity = statement.activity;
    final hasIssues = statement.issues.isNotEmpty;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: hasIssues
              ? AppTheme.statusAmber.withValues(alpha: 0.5)
              : theme.colorScheme.outline.withValues(alpha: 0.15),
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DepotStatementHeader(
              statement: statement,
              onToggle: onToggle,
              onEdit: onEdit,
              onRemove: onRemove,
              onShowText: onShowText,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: activity == null
                  ? Text(
                      l10n.depotImportNoData,
                      style: theme.textTheme.bodySmall,
                    )
                  : DepotActivityFields(activity: activity),
            ),
            if (hasIssues) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: statement.issues
                      .map(
                        (issue) => StatusBadge(
                          label: DepotLabels.issue(l10n, issue),
                          color: AppTheme.statusAmber,
                          icon: Icons.warning_amber_rounded,
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
