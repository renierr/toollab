import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/providers/app_state.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/readable_width.dart';

import '../news_catalog.dart';
import '../news_l10n.dart';
import '../news_state.dart';
import '../news_sync_helper.dart';
import 'news_category_dropdown.dart';

class NewsSourcePickerPage extends StatelessWidget {
  static const double _maxWidth = 720;

  const NewsSourcePickerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.newsAddSource),
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.newsBrowseTab),
              Tab(text: l10n.newsCustomTab),
            ],
          ),
        ),
        body: const TabBarView(children: [_BrowseTab(), _CustomTab()]),
      ),
    );
  }
}

class _BrowseTab extends StatefulWidget {
  const _BrowseTab();

  @override
  State<_BrowseTab> createState() => _BrowseTabState();
}

class _BrowseTabState extends State<_BrowseTab> with DisposeCleanup {
  late final TextEditingController _search;
  String? _category;
  final Set<String> _adding = {};

  @override
  void initState() {
    super.initState();
    _search = TextEditingController();
    onDispose(_search.dispose);
  }

  Future<void> _add(NewsCatalogSource source, String categoryId) async {
    if (_adding.contains(source.feedUrl)) return;
    final appState = context.read<AppState>();
    setState(() => _adding.add(source.feedUrl));
    try {
      await context.read<NewsState>().addCatalogSource(source, categoryId);
      unawaited(syncNewsSources(appState));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).newsSourceAdded)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).newsSourceInvalid)),
      );
    } finally {
      if (mounted) setState(() => _adding.remove(source.feedUrl));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = context.watch<NewsState>();
    final query = _search.text.trim().toLowerCase();
    final addedFeeds = state.sources.map((source) => source.feedUrl).toSet();

    final groups = <String, List<NewsCatalogSource>>{};
    for (final entry in NewsCatalog.byCategory.entries) {
      if (entry.key == NewsCatalog.customCategory) continue;
      if (_category != null && _category != entry.key) continue;
      final matching = entry.value.where((source) {
        if (query.isEmpty) return true;
        final category = newsCategoryLabel(l10n, entry.key).toLowerCase();
        return source.title.toLowerCase().contains(query) ||
            category.contains(query) ||
            source.feedUrl.toLowerCase().contains(query);
      }).toList();
      if (matching.isNotEmpty) groups[entry.key] = matching;
    }

    return ReadableScrollPadding(
      maxWidth: NewsSourcePickerPage._maxWidth,
      builder: (context, inset) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8) + inset,
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: l10n.newsSearchSources,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _search.clear();
                          setState(() {});
                        },
                      ),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12) + inset,
              children: [
                ChoiceChip(
                  label: Text(l10n.newsCategoryAll),
                  selected: _category == null,
                  onSelected: (_) => setState(() => _category = null),
                ),
                for (final category in NewsCatalog.categories)
                  if (category.id != NewsCatalog.customCategory)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: ChoiceChip(
                        label: Text(newsCategoryLabel(l10n, category.id)),
                        selected: _category == category.id,
                        onSelected: (_) =>
                            setState(() => _category = category.id),
                      ),
                    ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: groups.isEmpty
                ? Center(child: Text(l10n.newsNoSearchResults))
                : ListView(
                    padding: const EdgeInsets.only(bottom: 24) + inset,
                    children: [
                      for (final entry in groups.entries) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
                          child: Text(
                            newsCategoryLabel(l10n, entry.key).toUpperCase(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppTheme.accentAmber,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        for (final source in entry.value)
                          _CatalogTile(
                            source: source,
                            added: addedFeeds.contains(source.feedUrl),
                            adding: _adding.contains(source.feedUrl),
                            onAdd: () => _add(source, entry.key),
                          ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _CustomTab extends StatefulWidget {
  const _CustomTab();

  @override
  State<_CustomTab> createState() => _CustomTabState();
}

class _CustomTabState extends State<_CustomTab> with DisposeCleanup {
  late final TextEditingController _url;
  late final TextEditingController _name;
  String _category = NewsCatalog.customCategory;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _url = TextEditingController();
    _name = TextEditingController();
    onDispose(() {
      _url.dispose();
      _name.dispose();
    });
  }

  Future<void> _add() async {
    final l10n = AppLocalizations.of(context);
    final state = context.read<NewsState>();
    final appState = context.read<AppState>();
    final url = _url.text.trim();
    final invalid = newsFeedUrlError(l10n, url);
    if (invalid != null) {
      setState(() => _error = invalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await state.addCustomSource(
        feedUrl: url,
        title: _name.text,
        category: _category,
      );
      unawaited(syncNewsSources(appState));
      if (!mounted) return;
      _url.clear();
      _name.clear();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.newsSourceAdded)));
    } on NewsSourceExistsException {
      if (mounted) setState(() => _error = l10n.newsSourceExists);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = l10n.newsSourceInvalidDetail(newsErrorText(l10n, e)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return ReadableScrollPadding(
      maxWidth: NewsSourcePickerPage._maxWidth,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      builder: (context, padding) => ListView(
        padding: padding,
        children: [
          Text(
            l10n.newsCustomSection,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.newsCustomHint,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: l10n.newsSourceUrl,
              hintText: l10n.newsSourceUrlHint,
              prefixIcon: const Icon(Icons.rss_feed),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            decoration: InputDecoration(
              labelText: l10n.newsCustomNameOptional,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          NewsCategoryDropdown(
            value: _category,
            onChanged: (value) => setState(() => _category = value),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _busy ? null : _add,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add),
            label: Text(_busy ? l10n.newsAdding : l10n.newsAddFeed),
          ),
        ],
      ),
    );
  }
}

class _CatalogTile extends StatelessWidget {
  final NewsCatalogSource source;
  final bool added;
  final bool adding;
  final VoidCallback onAdd;

  const _CatalogTile({
    required this.source,
    required this.added,
    required this.adding,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return ListTile(
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: AppTheme.accentAmber.withValues(alpha: 0.14),
        child: Icon(
          added ? Icons.check : Icons.rss_feed,
          size: 18,
          color: AppTheme.accentAmber,
        ),
      ),
      title: Text(
        source.title,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        Uri.tryParse(source.feedUrl)?.host ?? source.feedUrl,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
      ),
      trailing: adding
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : added
          ? Text(
              l10n.newsAlreadyAdded,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            )
          : IconButton(
              onPressed: onAdd,
              icon: const Icon(Icons.add_circle_outline),
              tooltip: l10n.commonAdd,
            ),
      onTap: added || adding ? null : onAdd,
    );
  }
}
