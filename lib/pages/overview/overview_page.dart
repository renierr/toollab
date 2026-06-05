import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/constants.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/core/tool_registry.dart';
import 'package:tool_lab/providers/app_state.dart';
import 'package:tool_lab/widgets/section_header.dart';
import 'package:tool_lab/pages/overview/settings_dialog.dart';
import 'section_grid.dart';

class OverviewPage extends StatefulWidget {
  const OverviewPage({super.key});

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _collapsedSections = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

    if (compact) {
      const minHeight = 76.0;
      final defaultRatio = width < 400 ? 4.0 : (width < 600 ? 2.8 : 3.0);
      final heightWithDefaultRatio = cardWidth / defaultRatio;
      if (heightWithDefaultRatio < minHeight) {
        return cardWidth / minHeight;
      }
      return defaultRatio;
    }

    const minHeight = 145.0;
    final defaultRatio = width < 480 ? 1.1 : 1.2;
    final heightWithDefaultRatio = cardWidth / defaultRatio;
    if (heightWithDefaultRatio < minHeight) {
      return cardWidth / minHeight;
    }
    return defaultRatio;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isShort = MediaQuery.of(context).size.height < 600;
    final appBarHeight = isShort ? 40.0 : 56.0;

    final appState = context.watch<AppState>();
    final query = appState.searchQuery;
    final sortBy = appState.sortBy;
    final compact = appState.compactMode;

    var tools = ToolRegistry.all.where((t) {
      if (query.isEmpty) return true;
      final q = query.toLowerCase();
      return t.name.toLowerCase().contains(q) ||
          t.description.toLowerCase().contains(q);
    }).toList();

    if (sortBy == 'name') {
      tools.sort((a, b) => a.name.compareTo(b.name));
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

    // Favorites
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
              tooltip: 'Settings',
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
                        hintText: 'Search tools...',
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
                            'No tools found',
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
                                title: section.title,
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
