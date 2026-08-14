import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/image_preview_dialog.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';
import 'package:tool_lab/widgets/selectable_text_view.dart';
import 'package:tool_lab/widgets/status_badge.dart';

import '../db/sqlite_value.dart';

/// Result of editing a cell. [setNull] distinguishes "store NULL" from "store
/// the empty string", which the text field alone cannot express.
class CellEditResult {
  final Object? value;

  const CellEditResult(this.value);
}

/// Full value inspector for one cell, with an edit field when writes are
/// unlocked and the value is textual.
class SqliteCellDialog extends StatefulWidget {
  final String columnName;
  final Object? value;
  final bool editable;

  const SqliteCellDialog({
    super.key,
    required this.columnName,
    required this.value,
    required this.editable,
  });

  static Future<CellEditResult?> show({
    required BuildContext context,
    required String columnName,
    required Object? value,
    required bool editable,
  }) {
    return showDialog<CellEditResult>(
      context: context,
      builder: (_) => SqliteCellDialog(
        columnName: columnName,
        value: value,
        editable: editable,
      ),
    );
  }

  @override
  State<SqliteCellDialog> createState() => _SqliteCellDialogState();
}

class _SqliteCellDialogState extends State<SqliteCellDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value?.toString() ?? '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _typeLabel(AppLocalizations l10n, SqlValueType type) => switch (type) {
    SqlValueType.nullValue => l10n.sqliteViewerNull,
    SqlValueType.integer => 'INTEGER',
    SqlValueType.real => 'REAL',
    SqlValueType.text => 'TEXT',
    SqlValueType.blob => 'BLOB',
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final type = sqlValueTypeOf(widget.value);
    final blob = asBlob(widget.value);
    final blobText = blob == null ? null : decodeBlobAsText(blob);
    final canEdit = widget.editable && type != SqlValueType.blob;

    return ResponsiveAlertDialog(
      title: Text(
        widget.columnName,
        style: const TextStyle(fontFamily: 'monospace'),
      ),
      scrollable: true,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              StatusBadge(
                label: _typeLabel(l10n, type),
                color: theme.colorScheme.primary,
              ),
              if (blob != null)
                StatusBadge(
                  label: formatByteSize(blob.length),
                  color: theme.colorScheme.tertiary,
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (blob != null)
            _BlobBody(bytes: blob, decodedText: blobText)
          else if (canEdit)
            TextField(
              controller: _controller,
              maxLines: 8,
              minLines: 3,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              decoration: const InputDecoration(border: OutlineInputBorder()),
            )
          else
            SelectableTextView(
              text: widget.value?.toString() ?? '',
              emptyMessage: type == SqlValueType.nullValue
                  ? l10n.sqliteViewerNull
                  : l10n.sqliteViewerEmptyValue,
              maxHeight: 320,
            ),
        ],
      ),
      actions: [
        if (widget.value != null)
          TextButton(
            onPressed: () {
              final text = blob != null
                  ? (blobText ?? hexDump(blob))
                  : widget.value.toString();
              Clipboard.setData(ClipboardData(text: text));
            },
            child: Text(l10n.commonCopy),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonClose),
        ),
        if (canEdit) ...[
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(const CellEditResult(null)),
            child: Text(l10n.sqliteViewerSetNull),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.of(context).pop(CellEditResult(_controller.text)),
            child: Text(l10n.commonSave),
          ),
        ],
      ],
    );
  }
}

class _BlobBody extends StatelessWidget {
  final Uint8List bytes;
  final String? decodedText;

  const _BlobBody({required this.bytes, required this.decodedText});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (looksLikeImage(bytes)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: Image.memory(bytes, fit: BoxFit.contain),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => ImagePreviewDialog.show(
                context: context,
                image: MemoryImage(bytes),
              ),
              icon: const Icon(Icons.zoom_in, size: 18),
              label: Text(l10n.sqliteViewerShowImage),
            ),
          ),
        ],
      );
    }

    return SelectableTextView(
      text: decodedText ?? hexDump(bytes),
      emptyMessage: l10n.sqliteViewerEmptyValue,
      maxHeight: 320,
    );
  }
}
