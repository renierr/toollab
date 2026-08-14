import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/collapsible_section.dart';
import 'package:tool_lab/widgets/markdown_code_block.dart';
import 'package:tool_lab/widgets/status_badge.dart';

import '../config.dart';
import '../db/sqlite_models.dart';

/// Columns, indexes, foreign keys and the original DDL of the selected object.
class SqliteTableDetail extends StatelessWidget {
  final TableSchema schema;

  const SqliteTableDetail({super.key, required this.schema});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final accent = SqliteViewerTool.config.accentColor;
    final ddl = schema.object.sql;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: CollapsibleSection(
        icon: Icons.schema_outlined,
        iconColor: accent,
        title: l10n.sqliteViewerSchema,
        initiallyExpanded: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            ...schema.columns.map((column) => _ColumnRow(column: column)),
            if (schema.indexes.isNotEmpty) ...[
              const SizedBox(height: 12),
              _SubHeading(text: l10n.sqliteViewerIndexes),
              ...schema.indexes.map(
                (index) => _IndexRow(info: index, l10n: l10n),
              ),
            ],
            if (schema.foreignKeys.isNotEmpty) ...[
              const SizedBox(height: 12),
              _SubHeading(text: l10n.sqliteViewerForeignKeys),
              ...schema.foreignKeys.map(
                (fk) => _MonoLine(
                  text:
                      '${fk.fromColumn} → ${fk.targetTable}(${fk.targetColumn})',
                ),
              ),
            ],
            if (ddl != null && ddl.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              _SubHeading(text: l10n.sqliteViewerDdl),
              const SizedBox(height: 4),
              MarkdownCodeBlock(code: ddl, fenceLanguage: 'sql'),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _SubHeading extends StatelessWidget {
  final String text;

  const _SubHeading({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.bold,
        letterSpacing: 1.1,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _MonoLine extends StatelessWidget {
  final String text;

  const _MonoLine({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Text(
        text,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
      ),
    );
  }
}

class _ColumnRow extends StatelessWidget {
  final ColumnInfo column;

  const _ColumnRow({required this.column});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final type = column.declaredType.trim();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            column.name,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (type.isNotEmpty)
            StatusBadge(label: type, color: theme.colorScheme.primary),
          if (column.isPrimaryKey)
            StatusBadge(
              label: l10n.sqliteViewerPrimaryKey,
              color: AppTheme.statusAmber,
              icon: Icons.key,
            ),
          if (column.notNull)
            StatusBadge(
              label: l10n.sqliteViewerNotNull,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          if (column.defaultValue != null)
            Text(
              l10n.sqliteViewerDefaultValue(column.defaultValue!),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

class _IndexRow extends StatelessWidget {
  final IndexInfo info;
  final AppLocalizations l10n;

  const _IndexRow({required this.info, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            info.name,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
          if (info.unique)
            StatusBadge(
              label: l10n.sqliteViewerUnique,
              color: AppTheme.statusGreen,
            ),
          Text(
            '(${info.columns.join(', ')})',
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
