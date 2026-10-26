import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/tool_chip.dart';

class DepotImportToolbar extends StatelessWidget {
  final int activityCount;
  final int issueCount;
  final bool isImporting;
  final int importDone;
  final int importTotal;
  final VoidCallback onAdd;
  final VoidCallback onClear;
  final VoidCallback onExport;

  const DepotImportToolbar({
    super.key,
    required this.activityCount,
    required this.issueCount,
    required this.isImporting,
    required this.importDone,
    required this.importTotal,
    required this.onAdd,
    required this.onClear,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            isImporting
                ? l10n.depotImportReading(importDone, importTotal)
                : l10n.depotImportActivityCount(activityCount),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          if (!isImporting && issueCount > 0)
            Text(
              l10n.depotImportIssueCount(issueCount),
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.statusAmber,
                fontWeight: FontWeight.w600,
              ),
            ),
          ToolChip(icon: Icons.add, label: l10n.depotImportAdd, onTap: onAdd),
          ToolChip(
            icon: Icons.file_download_outlined,
            label: l10n.depotImportExport,
            onTap: onExport,
          ),
          ToolChip(
            icon: Icons.delete_sweep_outlined,
            label: l10n.depotImportClear,
            onTap: onClear,
          ),
        ],
      ),
    );
  }
}
