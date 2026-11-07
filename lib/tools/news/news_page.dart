import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/providers/app_state.dart';
import 'package:tool_lab/widgets/tool_layout.dart';

import 'config.dart';
import 'news_article.dart';
import 'news_state.dart';
import 'news_sync_delegate.dart';
import 'widgets/news_empty_view.dart';
import 'widgets/news_list.dart';
import 'widgets/news_reader_page.dart';
import 'widgets/news_settings_page.dart';
import 'widgets/news_source_filter_bar.dart';
import 'widgets/news_source_picker_page.dart';

class NewsPage extends StatefulWidget {
  const NewsPage({super.key});

  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> with DisposeCleanup {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    if (!mounted) return;
    final state = context.read<NewsState>();
    await state.init();
    if (!mounted) return;
    await _syncSources();
  }

  Future<void> _syncSources() async {
    final appState = context.read<AppState>();
    final state = context.read<NewsState>();
    if (!appState.syncsTool(NewsTool.config.id)) return;
    try {
      final result = await appState.syncWithBackend([NewsSyncDelegate()]);
      final pulled = result?['pulled'] ?? 0;
      if (!mounted || pulled == 0) return;
      await state.reload();
      if (mounted && state.refreshOnOpen) {
        unawaited(state.refresh(only: state.enabledSources));
      }
    } catch (e) {
      debugLog('[News] Source sync on open failed: $e');
    }
  }

  Future<void> _refresh() async {
    final state = context.read<NewsState>();
    final l10n = AppLocalizations.of(context);
    await state.refresh();
    if (!mounted) return;
    final message = state.lastRefreshFailures > 0
        ? l10n.newsRefreshFailed(state.lastRefreshFailures)
        : state.lastRefreshAdded > 0
        ? l10n.newsRefreshAdded(state.lastRefreshAdded)
        : l10n.newsRefreshNoNew;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openArticle(NewsArticle article) async {
    final state = context.read<NewsState>();
    await state.markRead(article);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NewsReaderPage(
          article: article,
          source: state.sourceFor(article.sourceShortId),
        ),
      ),
    );
  }

  Future<void> _openSettings() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const NewsSettingsPage()));
  }

  Future<void> _openPicker() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const NewsSourcePickerPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<NewsState>();

    return ToolLayout(
      title: NewsTool.config.localizedName(l10n),
      actions: [
        IconButton(
          onPressed: () => state.setHideRead(!state.hideRead),
          tooltip: state.hideRead ? l10n.newsShowAll : l10n.newsUnreadOnly,
          icon: Badge.count(
            count: state.totalUnread,
            isLabelVisible: state.totalUnread > 0,
            child: Icon(
              state.hideRead ? Icons.filter_alt : Icons.filter_alt_off,
            ),
          ),
        ),
        IconButton(
          onPressed: state.isRefreshing ? null : _refresh,
          tooltip: l10n.newsRefresh,
          icon: state.isRefreshing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh),
        ),
        IconButton(
          onPressed: _openSettings,
          tooltip: l10n.commonSettings,
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
      child: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                NewsSourceFilterBar(
                  sources: state.sources,
                  selectedSourceId: state.selectedSourceId,
                  unreadCounts: state.unreadCounts,
                  totalUnread: state.totalUnread,
                  onSelected: state.setSelectedSource,
                ),
                if (state.isRefreshing)
                  const LinearProgressIndicator(minHeight: 2),
                Expanded(
                  child: NewsList(
                    articles: state.articles,
                    sourceResolver: state.sourceFor,
                    markReadOnScroll: state.markReadOnScroll,
                    empty: NewsEmptyView(
                      hasSources: state.sources.isNotEmpty,
                      hideRead: state.hideRead,
                      onAddSources: _openPicker,
                      onRefresh: _refresh,
                      onShowAll: () => state.setHideRead(false),
                    ),
                    onRefresh: _refresh,
                    onOpen: _openArticle,
                    onSeen: (article) {
                      unawaited(state.markRead(article));
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
