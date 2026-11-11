import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/responsive_layout.dart';

import '../x_feed_state.dart';
import '../x_login_actions.dart';
import 'x_search_view.dart';
import 'x_timeline_view.dart';

/// The logged-in tool: a rail beside the feed when there is room (desktop,
/// TV), a bottom bar on phones. Visited tabs stay alive to keep their scroll.
class XFeedShell extends StatefulWidget {
  const XFeedShell({super.key});

  @override
  State<XFeedShell> createState() => _XFeedShellState();
}

class _XFeedShellState extends State<XFeedShell> {
  final Set<XFeedTab> _visited = {};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<XFeedState>();
    final tab = state.tab;
    _visited.add(tab);

    final destinations = [
      (XFeedTab.forYou, Icons.home_outlined, Icons.home, l10n.xFeedForYou),
      (
        XFeedTab.following,
        Icons.people_outline,
        Icons.people,
        l10n.xFeedFollowing,
      ),
      (
        XFeedTab.bookmarks,
        Icons.bookmark_border,
        Icons.bookmark,
        l10n.xFeedBookmarks,
      ),
      (XFeedTab.search, Icons.search, Icons.search, l10n.commonSearch),
    ];
    final index = destinations.indexWhere((d) => d.$1 == tab);

    final content = IndexedStack(
      index: index,
      children: [
        for (final d in destinations)
          _visited.contains(d.$1)
              ? _TabContent(tab: d.$1, active: d.$1 == tab)
              : const SizedBox.shrink(),
      ],
    );

    final body = Column(
      children: [
        if (state.sessionExpired)
          MaterialBanner(
            content: Text(l10n.xFeedSessionExpired),
            leading: const Icon(Icons.lock_clock_outlined),
            actions: [
              TextButton(
                onPressed: () => XLoginActions.webLogin(context),
                child: Text(l10n.xFeedLogIn),
              ),
            ],
          ),
        Expanded(child: content),
      ],
    );

    void select(int i) => state.setTab(destinations[i].$1);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.canSplit) {
          return Row(
            children: [
              NavigationRail(
                selectedIndex: index,
                onDestinationSelected: select,
                labelType: NavigationRailLabelType.all,
                destinations: [
                  for (final d in destinations)
                    NavigationRailDestination(
                      icon: Icon(d.$2),
                      selectedIcon: Icon(d.$3),
                      label: Text(d.$4),
                    ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: body),
            ],
          );
        }
        return Column(
          children: [
            Expanded(child: body),
            NavigationBar(
              selectedIndex: index,
              onDestinationSelected: select,
              height: 64,
              labelBehavior:
                  NavigationDestinationLabelBehavior.onlyShowSelected,
              destinations: [
                for (final d in destinations)
                  NavigationDestination(
                    icon: Icon(d.$2),
                    selectedIcon: Icon(d.$3),
                    label: d.$4,
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _TabContent extends StatelessWidget {
  final XFeedTab tab;
  final bool active;

  const _TabContent({required this.tab, required this.active});

  @override
  Widget build(BuildContext context) {
    final state = context.read<XFeedState>();
    final home = tab == XFeedTab.forYou || tab == XFeedTab.following;
    // Hidden tabs must not take part in D-pad traversal.
    return ExcludeFocus(
      excluding: !active,
      child: tab == XFeedTab.search
          ? const XSearchView()
          : XTimelineView(
              controller: state.controllerFor(tab),
              applyFilters: home,
              onSeen: home ? state.markSeen : null,
              emptyMessage: tab == XFeedTab.bookmarks
                  ? AppLocalizations.of(context).xFeedBookmarksEmpty
                  : null,
            ),
    );
  }
}
