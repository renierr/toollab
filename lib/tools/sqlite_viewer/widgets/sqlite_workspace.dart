import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/responsive_layout.dart';

import '../config.dart';
import '../sqlite_viewer_state.dart';
import 'sqlite_data_tab.dart';
import 'sqlite_object_list.dart';
import 'sqlite_overview_tab.dart';
import 'sqlite_source_banner.dart';
import 'sqlite_sql_tab.dart';

class SqliteWorkspace extends StatelessWidget {
  const SqliteWorkspace({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isBusy = context.select<SqliteViewerState, bool>((s) => s.isBusy);
    final isDesktop = ResponsiveLayout.isDesktop(context);

    const tabs = TabBarView(
      children: [SqliteOverviewTab(), SqliteDataTab(), SqliteSqlTab()],
    );

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const SqliteSourceBanner(),
          TabBar(
            labelColor: SqliteViewerTool.config.accentColor,
            indicatorColor: SqliteViewerTool.config.accentColor,
            unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
            tabs: [
              Tab(text: l10n.sqliteViewerTabOverview),
              Tab(text: l10n.sqliteViewerTabData),
              Tab(text: l10n.sqliteViewerTabSql),
            ],
          ),
          SizedBox(
            height: 2,
            child: isBusy ? const LinearProgressIndicator(minHeight: 2) : null,
          ),
          Expanded(
            child: isDesktop
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 260,
                        child: Material(
                          color: theme.colorScheme.surfaceContainerLow,
                          child: const SqliteObjectList(),
                        ),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(child: tabs),
                    ],
                  )
                : tabs,
          ),
        ],
      ),
    );
  }
}
