import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';

import '../sqlite_viewer_state.dart';

/// One-line honesty strip: says when the file on screen is a copy, when it is
/// one of ToolLab's own databases, and when writes are unlocked.
class SqliteSourceBanner extends StatelessWidget {
  const SqliteSourceBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = context.watch<SqliteViewerState>();

    final (String message, Color color, IconData icon) = state.editMode
        ? (l10n.sqliteViewerEditModeBanner, AppTheme.statusOrange, Icons.edit)
        : state.isInternal
        ? (
            l10n.sqliteViewerInternalNotice,
            AppTheme.statusBlue,
            Icons.inventory_2_outlined,
          )
        : state.isTempCopy
        ? (
            l10n.sqliteViewerSnapshotNotice,
            AppTheme.statusBlue,
            Icons.content_copy_outlined,
          )
        : (
            l10n.sqliteViewerReadOnlyNotice,
            theme.colorScheme.onSurfaceVariant,
            Icons.lock_outline,
          );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: color.withValues(alpha: 0.12),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
