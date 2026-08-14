import 'package:flutter/material.dart';

import '../db/sqlite_value.dart';

/// Virtualized result grid: a sticky header over a lazy row list, both moving
/// together horizontally so wide tables stay readable.
class SqliteDataGrid extends StatefulWidget {
  final List<String> columns;
  final List<List<Object?>> rows;
  final String emptyMessage;
  final String? sortColumn;
  final bool sortDescending;
  final ValueChanged<String>? onSort;
  final void Function(int rowIndex, int columnIndex)? onCellTap;
  final void Function(int rowIndex)? onRowLongPress;

  /// Absolute index of the first row, so the row-number gutter keeps counting
  /// across pages.
  final int rowNumberOffset;

  const SqliteDataGrid({
    super.key,
    required this.columns,
    required this.rows,
    required this.emptyMessage,
    this.sortColumn,
    this.sortDescending = false,
    this.onSort,
    this.onCellTap,
    this.onRowLongPress,
    this.rowNumberOffset = 0,
  });

  @override
  State<SqliteDataGrid> createState() => _SqliteDataGridState();
}

class _SqliteDataGridState extends State<SqliteDataGrid> {
  static const double _rowHeight = 34.0;
  static const double _gutterWidth = 56.0;
  static const double _charWidth = 7.6;
  static const double _minColumnWidth = 90.0;
  static const double _maxColumnWidth = 320.0;
  static const int _sampleRows = 30;

  final ScrollController _horizontal = ScrollController();
  final ScrollController _vertical = ScrollController();

  @override
  void dispose() {
    _horizontal.dispose();
    _vertical.dispose();
    super.dispose();
  }

  List<double> _columnWidths() {
    final sample = widget.rows.length > _sampleRows
        ? widget.rows.sublist(0, _sampleRows)
        : widget.rows;
    return List.generate(widget.columns.length, (index) {
      var longest = widget.columns[index].length + 2;
      for (final row in sample) {
        if (index >= row.length) continue;
        final length = formatCellPreview(row[index], maxChars: 60).length;
        if (length > longest) longest = length;
      }
      final width = longest * _charWidth + 24;
      return width.clamp(_minColumnWidth, _maxColumnWidth).toDouble();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.columns.isEmpty || widget.rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            widget.emptyMessage,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final widths = _columnWidths();
    final totalWidth =
        _gutterWidth + widths.fold<double>(0, (sum, width) => sum + width);

    return Scrollbar(
      controller: _horizontal,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _horizontal,
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: totalWidth,
          child: Column(
            children: [
              _GridHeader(
                columns: widget.columns,
                widths: widths,
                gutterWidth: _gutterWidth,
                height: _rowHeight,
                sortColumn: widget.sortColumn,
                sortDescending: widget.sortDescending,
                onSort: widget.onSort,
              ),
              const Divider(height: 1),
              Expanded(
                child: Scrollbar(
                  controller: _vertical,
                  thumbVisibility: true,
                  child: ListView.builder(
                    controller: _vertical,
                    itemExtent: _rowHeight,
                    itemCount: widget.rows.length,
                    itemBuilder: (context, index) => _GridRow(
                      values: widget.rows[index],
                      widths: widths,
                      gutterWidth: _gutterWidth,
                      rowNumber: widget.rowNumberOffset + index + 1,
                      striped: index.isOdd,
                      onCellTap: widget.onCellTap == null
                          ? null
                          : (column) => widget.onCellTap!(index, column),
                      onLongPress: widget.onRowLongPress == null
                          ? null
                          : () => widget.onRowLongPress!(index),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GridHeader extends StatelessWidget {
  final List<String> columns;
  final List<double> widths;
  final double gutterWidth;
  final double height;
  final String? sortColumn;
  final bool sortDescending;
  final ValueChanged<String>? onSort;

  const _GridHeader({
    required this.columns,
    required this.widths,
    required this.gutterWidth,
    required this.height,
    required this.sortColumn,
    required this.sortDescending,
    required this.onSort,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: height,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Row(
        children: [
          SizedBox(width: gutterWidth),
          for (var i = 0; i < columns.length; i++)
            InkWell(
              onTap: onSort == null ? null : () => onSort!(columns[i]),
              child: SizedBox(
                width: widths[i],
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          columns[i],
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (sortColumn == columns[i])
                        Icon(
                          sortDescending
                              ? Icons.arrow_downward
                              : Icons.arrow_upward,
                          size: 12,
                          color: theme.colorScheme.primary,
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GridRow extends StatelessWidget {
  final List<Object?> values;
  final List<double> widths;
  final double gutterWidth;
  final int rowNumber;
  final bool striped;
  final ValueChanged<int>? onCellTap;
  final VoidCallback? onLongPress;

  const _GridRow({
    required this.values,
    required this.widths,
    required this.gutterWidth,
    required this.rowNumber,
    required this.striped,
    required this.onCellTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onLongPress: onLongPress,
      child: Container(
        color: striped
            ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.18)
            : null,
        child: Row(
          children: [
            SizedBox(
              width: gutterWidth,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  '$rowNumber',
                  textAlign: TextAlign.right,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.6,
                    ),
                  ),
                ),
              ),
            ),
            for (var i = 0; i < widths.length; i++)
              InkWell(
                onTap: onCellTap == null ? null : () => onCellTap!(i),
                child: SizedBox(
                  width: widths[i],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _CellText(
                        value: i < values.length ? values[i] : null,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CellText extends StatelessWidget {
  final Object? value;

  const _CellText({required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final type = sqlValueTypeOf(value);

    if (type == SqlValueType.nullValue) {
      return Text(
        'NULL',
        style: theme.textTheme.bodySmall?.copyWith(
          fontFamily: 'monospace',
          fontStyle: FontStyle.italic,
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
        ),
      );
    }

    final isNumeric = type == SqlValueType.integer || type == SqlValueType.real;
    return Text(
      formatCellPreview(value, maxChars: 80),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodySmall?.copyWith(
        fontFamily: 'monospace',
        color: type == SqlValueType.blob
            ? theme.colorScheme.tertiary
            : isNumeric
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurface,
      ),
    );
  }
}
