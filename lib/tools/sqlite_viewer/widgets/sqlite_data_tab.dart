import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/confirm_action_dialog.dart';
import 'package:tool_lab/widgets/custom_notification.dart';

import '../sqlite_viewer_state.dart';
import 'sqlite_cell_dialog.dart';
import 'sqlite_data_grid.dart';
import 'sqlite_data_toolbar.dart';
import 'sqlite_row_edit_dialog.dart';
import 'sqlite_table_detail.dart';

class SqliteDataTab extends StatelessWidget {
  const SqliteDataTab({super.key});

  Future<void> _onCellTap(
    BuildContext context,
    int rowIndex,
    int columnIndex,
  ) async {
    final state = context.read<SqliteViewerState>();
    final l10n = AppLocalizations.of(context);
    final editable = state.editMode && (state.selected?.isEditable ?? false);
    final value = state.page.rows[rowIndex][columnIndex];

    final result = await SqliteCellDialog.show(
      context: context,
      columnName: state.page.columns[columnIndex],
      value: value,
      editable: editable,
    );
    if (result == null || !context.mounted) return;

    final ok = await state.updateCell(rowIndex, columnIndex, result.value);
    if (!ok && context.mounted) {
      showNotificationDialog(
        context,
        l10n.sqliteViewerWriteFailed,
        isError: true,
      );
    }
  }

  Future<void> _onRowLongPress(BuildContext context, int rowIndex) async {
    final state = context.read<SqliteViewerState>();
    final l10n = AppLocalizations.of(context);
    if (!state.editMode || !(state.selected?.isEditable ?? false)) return;

    final confirmed = await ConfirmActionDialog.show(
      context: context,
      title: l10n.sqliteViewerDeleteRow,
      message: l10n.sqliteViewerDeleteRowConfirm,
      cancelLabel: l10n.commonCancel,
      confirmLabel: l10n.commonDelete,
    );
    if (confirmed != true || !context.mounted) return;

    final ok = await state.deleteRow(rowIndex);
    if (!ok && context.mounted) {
      showNotificationDialog(
        context,
        l10n.sqliteViewerWriteFailed,
        isError: true,
      );
    }
  }

  Future<void> _onAddRow(BuildContext context) async {
    final state = context.read<SqliteViewerState>();
    final l10n = AppLocalizations.of(context);
    final schema = state.schema;
    if (schema == null) return;

    final values = await SqliteRowEditDialog.show(
      context: context,
      columns: schema.columns,
    );
    if (values == null || !context.mounted) return;

    final ok = await state.insertRow(values);
    if (!ok && context.mounted) {
      showNotificationDialog(
        context,
        l10n.sqliteViewerWriteFailed,
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<SqliteViewerState>();
    final schema = state.schema;
    final object = state.selected;

    if (object == null || schema == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            state.objects.isEmpty
                ? l10n.sqliteViewerNoObjects
                : l10n.sqliteViewerSelectObject,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    final canEditRows = state.editMode && object.isEditable;

    return Column(
      children: [
        const SizedBox(height: 4),
        // The schema block grows with the column count and the DDL, so it gets
        // its own scroll area instead of pushing the grid off screen.
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 280),
          child: SingleChildScrollView(
            child: SqliteTableDetail(schema: schema),
          ),
        ),
        SqliteDataToolbar(
          onAddRow: canEditRows ? () => _onAddRow(context) : null,
        ),
        const Divider(height: 1),
        Expanded(
          child: SqliteDataGrid(
            columns: state.page.columns,
            rows: state.page.rows,
            emptyMessage: l10n.sqliteViewerNoRows,
            sortColumn: state.sortColumn,
            sortDescending: state.sortDescending,
            rowNumberOffset: state.page.offset,
            onSort: context.read<SqliteViewerState>().sortBy,
            onCellTap: (row, column) => _onCellTap(context, row, column),
            onRowLongPress: canEditRows
                ? (row) => _onRowLongPress(context, row)
                : null,
          ),
        ),
      ],
    );
  }
}
