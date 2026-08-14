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

/// The tab index lives in the state rather than a [DefaultTabController] so the
/// schema drawer — which sits outside this subtree — can switch tabs too.
class SqliteWorkspace extends StatefulWidget {
  const SqliteWorkspace({super.key});

  @override
  State<SqliteWorkspace> createState() => _SqliteWorkspaceState();
}

class _SqliteWorkspaceState extends State<SqliteWorkspace>
    with SingleTickerProviderStateMixin {
  late final TabController _controller = TabController(
    length: kSqliteViewerTabCount,
    vsync: this,
  )..addListener(_onTabChanged);

  @override
  void dispose() {
    _controller.removeListener(_onTabChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_controller.indexIsChanging) return;
    context.read<SqliteViewerState>().setTabIndex(_controller.index);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = context.watch<SqliteViewerState>();
    final isDesktop = ResponsiveLayout.isDesktop(context);

    if (_controller.index != state.tabIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final target = context.read<SqliteViewerState>().tabIndex;
        if (_controller.index != target) _controller.animateTo(target);
      });
    }

    final tabs = TabBarView(
      controller: _controller,
      children: const [SqliteOverviewTab(), SqliteDataTab(), SqliteSqlTab()],
    );

    return Column(
      children: [
        const SqliteSourceBanner(),
        TabBar(
          controller: _controller,
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
          child: state.isBusy
              ? const LinearProgressIndicator(minHeight: 2)
              : null,
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
    );
  }
}
