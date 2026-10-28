import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/core/tool_registry.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/providers/app_state.dart';
import 'package:tool_lab/widgets/readable_width.dart';
import 'package:tool_lab/widgets/tool_layout.dart';
import 'package:tool_lab/widgets/tool_shortcut_row.dart';

enum _ShortcutFilter { all, homeScreen, drawer }

class ShortcutsSettingsPage extends StatefulWidget {
  const ShortcutsSettingsPage({super.key});

  @override
  State<ShortcutsSettingsPage> createState() => _ShortcutsSettingsPageState();
}

class _ShortcutsSettingsPageState extends State<ShortcutsSettingsPage>
    with DisposeCleanup {
  final TextEditingController _searchController = TextEditingController();
  _ShortcutFilter _filter = _ShortcutFilter.all;
  String _query = '';

  @override
  void initState() {
    super.initState();
    onDispose(_searchController.dispose);
  }

  bool _matches(ToolModel tool, AppState appState, AppLocalizations l10n) {
    final hasShortcut = appState.pinnedShortcuts[tool.id] ?? false;
    final hasDrawerIcon = appState.drawerIcons[tool.id] ?? false;
    final matchesFilter = switch (_filter) {
      _ShortcutFilter.all => true,
      _ShortcutFilter.homeScreen => hasShortcut,
      _ShortcutFilter.drawer => hasDrawerIcon,
    };
    if (!matchesFilter) return false;
    if (_query.isEmpty) return true;
    final haystack =
        '${tool.localizedName(l10n)} ${tool.localizedDescription(l10n)}'
            .toLowerCase();
    return haystack.contains(_query);
  }

  Future<void> _pin(ToolModel tool, String toolName) async {
    final appState = context.read<AppState>();
    final success = await appState.pinShortcut(tool.id, toolName);
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    _showMessage(
      success
          ? l10n.coreShortcutsPinRequested(toolName)
          : l10n.coreShortcutsPinFailed,
    );
  }

  Future<void> _toggleDrawer(ToolModel tool, String toolName) async {
    final appState = context.read<AppState>();
    final enabling = !(appState.drawerIcons[tool.id] ?? false);
    await appState.toggleDrawerIcon(tool.id);
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    _showMessage(
      enabling
          ? l10n.coreShortcutsDrawerEnabled(toolName)
          : l10n.coreShortcutsDrawerDisabled(toolName),
    );
  }

  void _showMessage(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final appState = context.watch<AppState>();
    final isAndroid = !kIsWeb && Platform.isAndroid;
    final sections = <(ToolSection, List<ToolModel>)>[];
    for (final section in ToolRegistry.sections.values) {
      final tools = ToolRegistry.all
          .where((tool) => tool.sectionId == section.id)
          .where((tool) => _matches(tool, appState, l10n))
          .toList();
      if (tools.isNotEmpty) sections.add((section, tools));
    }

    return ToolLayout(
      title: l10n.coreShortcutsTitle,
      child: ReadableWidth(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _ShortcutHint(text: l10n.coreShortcutsDirectAccessSubtitle),
            if (!isAndroid) ...[
              const SizedBox(height: 8),
              _PlatformNotice(text: l10n.coreShortcutsAndroidRequired),
            ],
            const SizedBox(height: 12),
            _ShortcutFilterBar(
              controller: _searchController,
              filter: _filter,
              onQueryChanged: (value) =>
                  setState(() => _query = value.trim().toLowerCase()),
              onFilterChanged: (filter) => setState(() => _filter = filter),
            ),
            if (sections.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Column(
                  children: [
                    Icon(
                      Icons.search_off_outlined,
                      size: 40,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.coreShortcutsNoMatches,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              )
            else
              for (final (section, tools) in sections)
                _ShortcutSection(
                  section: section,
                  tools: tools,
                  appState: appState,
                  enabled: isAndroid,
                  onPin: _pin,
                  onToggleDrawer: _toggleDrawer,
                ),
          ],
        ),
      ),
    );
  }
}

class _ShortcutHint extends StatelessWidget {
  final String text;

  const _ShortcutHint({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            Icons.shortcut_outlined,
            size: 20,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlatformNotice extends StatelessWidget {
  final String text;

  const _PlatformNotice({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShortcutFilterBar extends StatelessWidget {
  final TextEditingController controller;
  final _ShortcutFilter filter;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<_ShortcutFilter> onFilterChanged;

  const _ShortcutFilterBar({
    required this.controller,
    required this.filter,
    required this.onQueryChanged,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          onChanged: onQueryChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: l10n.coreShortcutsSearchHint,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: controller.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      controller.clear();
                      onQueryChanged('');
                    },
                  ),
            isDense: true,
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.4,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final entry in {
              _ShortcutFilter.all: l10n.coreShortcutsFilterAll,
              _ShortcutFilter.homeScreen: l10n.coreShortcutsFilterHomeScreen,
              _ShortcutFilter.drawer: l10n.coreShortcutsFilterDrawer,
            }.entries)
              ChoiceChip(
                label: Text(entry.value),
                selected: filter == entry.key,
                onSelected: (_) => onFilterChanged(entry.key),
              ),
          ],
        ),
      ],
    );
  }
}

class _ShortcutSection extends StatelessWidget {
  final ToolSection section;
  final List<ToolModel> tools;
  final AppState appState;
  final bool enabled;
  final Future<void> Function(ToolModel tool, String toolName) onPin;
  final Future<void> Function(ToolModel tool, String toolName) onToggleDrawer;

  const _ShortcutSection({
    required this.section,
    required this.tools,
    required this.appState,
    required this.enabled,
    required this.onPin,
    required this.onToggleDrawer,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
          child: Row(
            children: [
              Icon(section.icon, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  section.localizedTitle(l10n),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '${tools.length}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
        Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: theme.colorScheme.outline.withValues(alpha: 0.15),
            ),
          ),
          child: Column(
            children: [
              for (var i = 0; i < tools.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    indent: 56,
                    endIndent: 12,
                    color: theme.colorScheme.outline.withValues(alpha: 0.1),
                  ),
                ToolShortcutRow(
                  tool: tools[i],
                  hasShortcut: appState.pinnedShortcuts[tools[i].id] ?? false,
                  hasDrawerIcon: appState.drawerIcons[tools[i].id] ?? false,
                  enabled: enabled,
                  onPinPressed: () =>
                      onPin(tools[i], tools[i].localizedName(l10n)),
                  onDrawerIconChanged: (_) =>
                      onToggleDrawer(tools[i], tools[i].localizedName(l10n)),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
