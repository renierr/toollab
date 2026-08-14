import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

import '../db/sqlite_models.dart';

/// Insert dialog: one field per column, each with a NULL toggle so an omitted
/// value stays distinguishable from an empty string.
class SqliteRowEditDialog extends StatefulWidget {
  final List<ColumnInfo> columns;

  const SqliteRowEditDialog({super.key, required this.columns});

  static Future<Map<String, Object?>?> show({
    required BuildContext context,
    required List<ColumnInfo> columns,
  }) {
    return showDialog<Map<String, Object?>>(
      context: context,
      builder: (_) => SqliteRowEditDialog(columns: columns),
    );
  }

  @override
  State<SqliteRowEditDialog> createState() => _SqliteRowEditDialogState();
}

class _SqliteRowEditDialogState extends State<SqliteRowEditDialog> {
  final Map<String, TextEditingController> _controllers = {};
  final Set<String> _nullColumns = {};

  @override
  void initState() {
    super.initState();
    for (final column in widget.columns) {
      _controllers[column.name] = TextEditingController();
      if (!column.notNull) _nullColumns.add(column.name);
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final values = <String, Object?>{};
    for (final column in widget.columns) {
      if (_nullColumns.contains(column.name)) continue;
      values[column.name] = _controllers[column.name]!.text;
    }
    Navigator.of(context).pop(values);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ResponsiveAlertDialog(
      title: Text(l10n.sqliteViewerAddRow),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final column in widget.columns)
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          column.name,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        l10n.sqliteViewerNull,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      Checkbox(
                        value: _nullColumns.contains(column.name),
                        onChanged: (checked) => setState(() {
                          if (checked ?? false) {
                            _nullColumns.add(column.name);
                          } else {
                            _nullColumns.remove(column.name);
                          }
                        }),
                      ),
                    ],
                  ),
                  TextField(
                    controller: _controllers[column.name],
                    enabled: !_nullColumns.contains(column.name),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      border: const OutlineInputBorder(),
                      hintText: column.declaredType,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        ElevatedButton(onPressed: _submit, child: Text(l10n.commonAdd)),
      ],
    );
  }
}
