import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/confirm_action_dialog.dart';
import 'package:tool_lab/widgets/custom_notification.dart';
import 'package:tool_lab/widgets/info_card.dart';

import '../db/sqlite_models.dart';
import '../sqlite_viewer_state.dart';
import 'sqlite_data_grid.dart';
import 'sqlite_sql_editor.dart';

class SqliteSqlTab extends StatelessWidget {
  const SqliteSqlTab({super.key});

  Future<void> _run(BuildContext context) async {
    final state = context.read<SqliteViewerState>();
    final l10n = AppLocalizations.of(context);

    if (state.sql.trim().isEmpty) {
      showNotificationDialog(
        context,
        l10n.sqliteViewerQueryEmpty,
        isError: true,
      );
      return;
    }

    if (state.sqlNeedsEditMode) {
      if (!state.editMode) {
        showNotificationDialog(
          context,
          l10n.sqliteViewerReadOnlyRefusal,
          isError: true,
        );
        return;
      }
      final confirmed = await ConfirmActionDialog.show(
        context: context,
        title: l10n.sqliteViewerConfirmWriteTitle,
        message: l10n.sqliteViewerConfirmWriteMessage,
        cancelLabel: l10n.commonCancel,
        confirmLabel: l10n.sqliteViewerRun,
      );
      if (confirmed != true || !context.mounted) return;
    }

    await state.runSql();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = context.watch<SqliteViewerState>();
    final result = state.queryResult;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SqliteSqlEditor(onRun: () => _run(context)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () =>
                        context.read<SqliteViewerState>().setSql(''),
                    child: Text(l10n.commonClear),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: state.isRunningQuery
                        ? null
                        : () => _run(context),
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: Text(l10n.sqliteViewerRun),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: state.queryError != null
              ? SingleChildScrollView(
                  padding: const EdgeInsets.all(12.0),
                  child: InfoCard(
                    icon: Icons.error_outline,
                    title: l10n.sqliteViewerSqlError,
                    titleColor: AppTheme.statusRed,
                    borderColor: AppTheme.statusRed,
                    child: SelectableText(
                      state.queryError!,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                )
              : result == null
              ? Center(
                  child: Text(
                    l10n.sqliteViewerSqlIdle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : _QueryOutcome(result: result),
        ),
      ],
    );
  }
}

class _QueryOutcome extends StatelessWidget {
  final QueryResult result;

  const _QueryOutcome({required this.result});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    if (!result.isResultSet) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            result.kind == SqlStatementKind.write
                ? l10n.sqliteViewerRowsAffected(
                    '${result.affectedRows}',
                    '${result.elapsedMs}',
                  )
                : l10n.sqliteViewerStatementDone('${result.elapsedMs}'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.sqliteViewerRowsReturned(
                    '${result.rows.length}',
                    '${result.elapsedMs}',
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              if (result.truncated)
                Text(
                  l10n.sqliteViewerTruncated('${result.rows.length}'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.statusOrange,
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: SqliteDataGrid(
            columns: result.columns,
            rows: result.rows,
            emptyMessage: l10n.sqliteViewerNoRows,
          ),
        ),
      ],
    );
  }
}
