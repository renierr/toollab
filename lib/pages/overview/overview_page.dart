import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/constants.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/core/tool_registry.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/providers/app_state.dart';
import 'package:tool_lab/widgets/section_header.dart';
import 'package:tool_lab/pages/overview/settings_dialog.dart';
import 'section_grid.dart';

class OverviewPage extends StatefulWidget {
  const OverviewPage({super.key});

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> with DisposeCleanup {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _collapsedSections = {};

  @override
  void initState() {
    super.initState();
    onDispose(_searchController.dispose);
  }

  int _crossAxisCount(double width) {
    if (width < 400) return 1;
    if (width < 600) return 2;
    if (width < 900) return 3;
    return 4;
  }

  double _childAspectRatio(bool compact, double width) {
    final crossAxisCount = _crossAxisCount(width);
    final cardWidth = (width - 32 - (crossAxisCount - 1) * 12) / crossAxisCount;
    final targetHeight = compact ? 76.0 : 155.0;
    return cardWidth / targetHeight;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isShort = MediaQuery.sizeOf(context).height < 600;
    final appBarHeight = isShort ? 40.0 : 56.0;

    final appState = context.watch<AppState>();
    final query = appState.searchQuery;
    final sortBy = appState.sortBy;
    final compact = appState.compactMode;

    var tools = ToolRegistry.all.where((t) {
      if (query.isEmpty) return true;
      final q = query.toLowerCase();
      return t.localizedName(l10n).toLowerCase().contains(q) ||
          t.localizedDescription(l10n).toLowerCase().contains(q);
    }).toList();

    if (sortBy == 'name') {
      tools.sort(
        (a, b) => a.localizedName(l10n).compareTo(b.localizedName(l10n)),
      );
    } else if (sortBy == 'recent') {
      tools.sort((a, b) {
        final ta = appState.getLastUsed(a.id);
        final tb = appState.getLastUsed(b.id);
        return tb.compareTo(ta);
      });
    }

    final grouped = <ToolSection, List<ToolModel>>{};
    for (final tool in tools) {
      final section =
          ToolRegistry.sections[tool.sectionId] ??
          ToolSection(
            id: tool.sectionId,
            title: tool.sectionId,
            icon: Icons.folder_outlined,
          );
      grouped.putIfAbsent(section, () => []).add(tool);
    }

    final sectionOrder = ToolRegistry.sections.keys.toList();
    final orderedSections = <MapEntry<ToolSection, List<ToolModel>>>[];
    final remaining = Map<ToolSection, List<ToolModel>>.from(grouped);
    for (final id in sectionOrder) {
      final section = ToolRegistry.sections[id]!;
      final list = remaining.remove(section);
      if (list != null) orderedSections.add(MapEntry(section, list));
    }
    orderedSections.addAll(remaining.entries);

    final hasResults = tools.isNotEmpty;

    final favoriteTools = appState.favorites.isEmpty
        ? <ToolModel>[]
        : tools.where((t) => appState.isFavorite(t.id)).toList();

    final showFavorites = favoriteTools.isNotEmpty;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(appBarHeight),
        child: AppBar(
          toolbarHeight: appBarHeight,
          title: Text(
            AppConstants.appName,
            style: TextStyle(
              fontSize: isShort ? 16.0 : 20.0,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.tune_outlined, size: isShort ? 20 : null),
              onPressed: () => OverviewSettingsDialog.show(context),
              tooltip: l10n.commonSettings,
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = _crossAxisCount(constraints.maxWidth);

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) => appState.setSearchQuery(value),
                      decoration: InputDecoration(
                        hintText: l10n.coreOverviewSearchHint,
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  appState.setSearchQuery('');
                                },
                              )
                            : null,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
                if (!hasResults)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 48,
                            color: theme.colorScheme.onSurface.withAlpha(80),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            l10n.coreOverviewNoToolsFound,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurface.withAlpha(150),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  if (showFavorites)
                    SectionGrid(
                      sectionTools: favoriteTools,
                      crossAxisCount: crossAxisCount,
                      compact: compact,
                      childAspectRatio: _childAspectRatio(
                        compact,
                        constraints.maxWidth,
                      ),
                    ),
                  ...orderedSections
                      .map((entry) {
                        final section = entry.key;
                        final sectionTools = entry.value;
                        final isCollapsed = _collapsedSections.contains(
                          section.id,
                        );

                        return <Widget>[
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            sliver: SliverToBoxAdapter(
                              child: SectionHeader(
                                icon: section.icon,
                                title: section.localizedTitle(l10n),
                                toolCount: sectionTools.length,
                                isCollapsed: isCollapsed,
                                onToggle: () {
                                  setState(() {
                                    if (isCollapsed) {
                                      _collapsedSections.remove(section.id);
                                    } else {
                                      _collapsedSections.add(section.id);
                                    }
                                  });
                                },
                              ),
                            ),
                          ),
                          if (!isCollapsed)
                            SectionGrid(
                              sectionTools: sectionTools,
                              crossAxisCount: crossAxisCount,
                              compact: compact,
                              childAspectRatio: _childAspectRatio(
                                compact,
                                constraints.maxWidth,
                              ),
                            ),
                          SliverToBoxAdapter(
                            child: SizedBox(
                              height: sectionTools.isNotEmpty ? 8 : 0,
                            ),
                          ),
                        ];
                      })
                      .expand((list) => list),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
