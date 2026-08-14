import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/data_row.dart';
import 'package:tool_lab/widgets/info_card.dart';
import 'package:tool_lab/widgets/selectable_text_view.dart';
import 'package:tool_lab/widgets/status_badge.dart';

import '../db/sqlite_value.dart';
import '../sqlite_viewer_state.dart';

class SqliteOverviewTab extends StatelessWidget {
  const SqliteOverviewTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<SqliteViewerState>();
    final overview = state.overview;
    if (overview == null) return const SizedBox.shrink();

    final integrity = state.integrityResult;
    final integrityOk = integrity != null && integrity.trim() == 'ok';

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        InfoCard(
          icon: Icons.insert_drive_file_outlined,
          title: l10n.sqliteViewerSectionFile,
          child: Column(
            children: [
              InfoRow(
                label: l10n.sqliteViewerFileName,
                value: overview.fileName,
              ),
              InfoRow(
                label: l10n.sqliteViewerFileSize,
                value: formatByteSize(overview.fileSizeBytes),
              ),
              InfoRow(
                label: l10n.sqliteViewerFilePath,
                value: state.originalPath ?? overview.filePath,
              ),
              InfoRow(
                label: l10n.sqliteViewerSqliteVersion,
                value: overview.sqliteVersion,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        InfoCard(
          icon: Icons.tune_outlined,
          title: l10n.sqliteViewerSectionPragmas,
          child: Column(
            children: [
              InfoRow(
                label: l10n.sqliteViewerPageSize,
                value: formatByteSize(overview.pageSize),
              ),
              InfoRow(
                label: l10n.sqliteViewerPageCount,
                value: '${overview.pageCount}',
              ),
              InfoRow(
                label: l10n.sqliteViewerFreelistPages,
                value: '${overview.freelistCount}',
              ),
              InfoRow(
                label: l10n.sqliteViewerEncoding,
                value: overview.encoding,
              ),
              InfoRow(
                label: l10n.sqliteViewerJournalMode,
                value: overview.journalMode.toUpperCase(),
              ),
              InfoRow(
                label: l10n.sqliteViewerAutoVacuum,
                value: '${overview.autoVacuum}',
              ),
              InfoRow(
                label: l10n.sqliteViewerUserVersion,
                value: '${overview.userVersion}',
              ),
              InfoRow(
                label: l10n.sqliteViewerApplicationId,
                value: '${overview.applicationId}',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        InfoCard(
          icon: Icons.account_tree_outlined,
          title: l10n.sqliteViewerObjects,
          child: Column(
            children: [
              InfoRow(
                label: l10n.sqliteViewerTables,
                value: '${overview.tableCount}',
              ),
              InfoRow(
                label: l10n.sqliteViewerViews,
                value: '${overview.viewCount}',
              ),
              InfoRow(
                label: l10n.sqliteViewerIndexes,
                value: '${overview.indexCount}',
              ),
              InfoRow(
                label: l10n.sqliteViewerTriggers,
                value: '${overview.triggerCount}',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        InfoCard(
          icon: Icons.health_and_safety_outlined,
          title: l10n.sqliteViewerIntegrityTitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (integrity != null) ...[
                StatusBadge(
                  label: integrityOk
                      ? l10n.sqliteViewerIntegrityOk
                      : l10n.sqliteViewerIntegrityFailed,
                  color: integrityOk
                      ? AppTheme.statusGreen
                      : AppTheme.statusRed,
                  showDot: true,
                ),
                const SizedBox(height: 8),
                if (!integrityOk)
                  SelectableTextView(
                    text: integrity,
                    emptyMessage: l10n.sqliteViewerIntegrityEmpty,
                    maxHeight: 200,
                  ),
                const SizedBox(height: 8),
              ],
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: state.isBusy
                      ? null
                      : context.read<SqliteViewerState>().runIntegrityCheck,
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: Text(l10n.sqliteViewerRunIntegrityCheck),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
