import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/constants.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/core/tool_registry.dart';
import 'package:tool_lab/providers/app_state.dart';
import 'package:tool_lab/widgets/tool_card.dart';
import 'package:tool_lab/widgets/section_header.dart';
import 'package:tool_lab/pages/overview/settings_dialog.dart';

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

  double _childAspectRatio(bool compact) {
    return compact ? 3.5 : 1.3;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
      appBar: AppBar(
        title: Text(AppConstants.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_outlined),
            onPressed: () => OverviewSettingsDialog.show(context),
            tooltip: 'Settings',
          ),
        ],
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
                    _buildSectionGrid(
                      section: const ToolSection(
                        id: '__favorites__',
                        title: 'Favorites',
                        icon: Icons.star,
                      ),
                      sectionTools: favoriteTools,
                      crossAxisCount: crossAxisCount,
                      compact: compact,
                    ),
                  ...orderedSections
                      .map((entry) {
                        final section = entry.key;
                        final sectionTools = entry.value;
                        final isCollapsed = _collapsedSections.contains(
                          section.id,
                        );

                        return <Widget>[
                          SliverToBoxAdapter(
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
                          if (!isCollapsed)
                            SliverGrid(
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: crossAxisCount,
                                    crossAxisSpacing: 10,
                                    mainAxisSpacing: 10,
                                    childAspectRatio: _childAspectRatio(
                                      compact,
                                    ),
                                  ),
                              delegate: SliverChildBuilderDelegate((
                                context,
                                index,
                              ) {
                                final tool = sectionTools[index];
                                return ToolCard(
                                  tool: tool,
                                  compact: compact,
                                  onTap: () {
                                    context.read<AppState>().recordToolUsage(
                                      tool.id,
                                    );
                                    context.push(tool.route);
                                  },
                                );
                              }, childCount: sectionTools.length),
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

  Widget _buildSectionGrid({
    required ToolSection section,
    required List<ToolModel> sectionTools,
    required int crossAxisCount,
    required bool compact,
  }) {
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: _childAspectRatio(compact),
      ),
      delegate: SliverChildBuilderDelegate((context, index) {
        final tool = sectionTools[index];
        return ToolCard(
          tool: tool,
          compact: compact,
          onTap: () {
            context.read<AppState>().recordToolUsage(tool.id);
            context.push(tool.route);
          },
        );
      }, childCount: sectionTools.length),
    );
  }
}
