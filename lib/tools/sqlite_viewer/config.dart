import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/theme/theme.dart';

import 'sqlite_viewer_page.dart';
import 'sqlite_viewer_state.dart';

class SqliteViewerTool {
  SqliteViewerTool._();

  static ToolModel get config => ToolModel(
    id: 'sqlite-viewer',
    name: 'SQLite Viewer',
    description: 'Inspect SQLite databases: schema, tables and free SQL',
    icon: Icons.storage_outlined,
    route: '/sqlite-viewer',
    accentColor: AppTheme.accentTeal,
    sectionId: 'utilities',
    nameL10n: (l10n) => l10n.toolNameSqliteViewer,
    descriptionL10n: (l10n) => l10n.toolDescSqliteViewer,
    fileExtensions: const ['db', 'sqlite', 'sqlite3', 'db3'],
    shareTarget: const ShareTargetConfig(
      accept: [
        'application/vnd.sqlite3',
        'application/x-sqlite3',
        'application/octet-stream',
      ],
    ),
    createPage: (sd) => SqliteViewerPage(sharedFile: sd?.firstFile),
    stateProviders: () => [
      ChangeNotifierProvider<SqliteViewerState>(
        create: (_) => SqliteViewerState(),
      ),
    ],
  );
}
