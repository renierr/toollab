import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../db/sqlite_models.dart';
import '../sqlite_viewer_state.dart';

/// Grouped list of every schema object. Browsable objects select into the data
/// tab; indexes and triggers are shown for orientation only.
class SqliteObjectList extends StatelessWidget {
  final VoidCallback? onSelected;

  const SqliteObjectList({super.key, this.onSelected});

  IconData _iconFor(DbObjectType type) => switch (type) {
    DbObjectType.table => Icons.table_rows_outlined,
    DbObjectType.view => Icons.visibility_outlined,
    DbObjectType.indexObject => Icons.sort_outlined,
    DbObjectType.trigger => Icons.bolt_outlined,
  };

  String _titleFor(AppLocalizations l10n, DbObjectType type) => switch (type) {
    DbObjectType.table => l10n.sqliteViewerTables,
    DbObjectType.view => l10n.sqliteViewerViews,
    DbObjectType.indexObject => l10n.sqliteViewerIndexes,
    DbObjectType.trigger => l10n.sqliteViewerTriggers,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = context.watch<SqliteViewerState>();

    if (state.objects.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            l10n.sqliteViewerNoObjects,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final children = <Widget>[];
    for (final type in DbObjectType.values) {
      final group = state.objectsOfType(type);
      if (group.isEmpty) continue;
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            '${_titleFor(l10n, type)} (${group.length})',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
      for (final object in group) {
        final selected =
            state.selected?.name == object.name &&
            state.selected?.type == object.type;
        children.add(
          ListTile(
            dense: true,
            selected: selected,
            leading: Icon(_iconFor(type), size: 18),
            title: Text(
              object.name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
            subtitle: object.isBrowsable
                ? null
                : Text(
                    object.tableName,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
            enabled: object.isBrowsable,
            onTap: object.isBrowsable
                ? () {
                    context.read<SqliteViewerState>().selectObject(object);
                    onSelected?.call();
                  }
                : null,
          ),
        );
      }
    }

    return ListView(padding: EdgeInsets.zero, children: children);
  }
}
