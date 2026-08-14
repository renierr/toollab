import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/status_badge.dart';

import '../db/sqlite_value.dart';
import '../sqlite_viewer_state.dart';

class SqliteInternalDbList extends StatelessWidget {
  const SqliteInternalDbList({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = context.watch<SqliteViewerState>();
    final entries = state.internalDatabases;

    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text(
          l10n.sqliteViewerNoInternal,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Text(
            l10n.sqliteViewerInternalSubtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        ...entries.map(
          (entry) => ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.dataset_outlined),
            title: Text(entry.name, overflow: TextOverflow.ellipsis),
            subtitle: Text(formatByteSize(entry.sizeBytes)),
            trailing: entry.isLiveAppDatabase
                ? StatusBadge(
                    label: l10n.sqliteViewerAppDatabase,
                    color: AppTheme.statusBlue,
                  )
                : null,
            onTap: () => context.read<SqliteViewerState>().openInternal(entry),
          ),
        ),
      ],
    );
  }
}
