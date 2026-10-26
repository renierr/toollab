import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/status_badge.dart';

import '../depot_import_state.dart';
import '../depot_labels.dart';
import '../models/depot_activity.dart';
import 'depot_activity_fields.dart';
import 'depot_statement_header.dart';

class DepotStatementCard extends StatelessWidget {
  final ParsedStatement statement;
  final DepotUploadResult? upload;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onRemove;
  final VoidCallback onShowText;

  const DepotStatementCard({
    super.key,
    required this.statement,
    required this.onToggle,
    this.upload,
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
            if (upload case final upload?) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: StatusBadge(
                    label: switch (upload.status) {
                      DepotUploadStatus.uploaded => l10n.depotUploadStatusSent,
                      DepotUploadStatus.existing =>
                        l10n.depotUploadStatusExisting,
                      DepotUploadStatus.rejected =>
                        l10n.depotUploadStatusRejected,
                    },
                    color: upload.status == DepotUploadStatus.rejected
                        ? AppTheme.statusRed
                        : AppTheme.statusGreen,
                    icon: switch (upload.status) {
                      DepotUploadStatus.uploaded => Icons.cloud_done_outlined,
                      DepotUploadStatus.existing => Icons.done_all,
                      DepotUploadStatus.rejected => Icons.cloud_off_outlined,
                    },
                  ),
                ),
              ),
              if (upload.message case final message? when message.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                  child: Text(
                    message,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.statusRed,
                    ),
                  ),
                ),
            ],
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
