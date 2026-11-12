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
import 'news_sync_helper.dart';
import 'widgets/news_empty_view.dart';
import 'widgets/news_list.dart';
import 'widgets/news_reader_page.dart';
import 'widgets/news_settings_page.dart';
import 'widgets/news_source_filter_bar.dart';
import 'widgets/news_source_picker_page.dart';
import 'widgets/news_text_scale.dart';
import 'widgets/news_text_size_sheet.dart';

class NewsPage extends StatefulWidget {
  const NewsPage({super.key});

  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> with DisposeCleanup {
  static const Duration _readSyncDelay = Duration(seconds: 2);
  // Continuous scrolling keeps restarting the delay; this caps the wait.
  static const Duration _readSyncMaxDelay = Duration(seconds: 10);
  static const Duration _syncRetryDelay = Duration(seconds: 30);

  final ScrollController _scrollController = ScrollController();
  final FocusNode _actionsFocus = FocusNode(debugLabel: 'NewsActions');
  Timer? _readSyncTimer;
  DateTime? _readSyncDeadline;
  bool _syncWhenIdle = false;
  int _readGeneration = 0;
  AppState? _appState;

  @override
  void initState() {
    super.initState();
    final state = context.read<NewsState>();
    _readGeneration = state.readGeneration;
    void onStateChanged() {
      if (state.readGeneration == _readGeneration) return;
      _readGeneration = state.readGeneration;
      _scheduleReadSync();
    }

    state.addListener(onStateChanged);
    // Backgrounded apps may be killed before the read flush delay ends.
    final lifecycle = AppLifecycleListener(
      onHide: () => unawaited(state.flushReads()),
    );
    onDispose(() {
      lifecycle.dispose();
      _scrollController.dispose();
      _actionsFocus.dispose();
      state.removeListener(onStateChanged);
      final appState = _appState;
      final syncReads =
          _readSyncTimer?.isActive == true || state.hasUnsavedReads;
      final flushed = state.flushReads();
      if (appState != null && syncReads) {
        unawaited(flushed.then((_) => syncNewsSources(appState)));
      }
      _readSyncTimer?.cancel();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  void _scheduleReadSync() {
    final now = DateTime.now();
    final deadline = _readSyncDeadline ??= now.add(_readSyncMaxDelay);
    final untilDeadline = deadline.difference(now);
    _startSyncTimer(
      untilDeadline < _readSyncDelay ? untilDeadline : _readSyncDelay,
    );
  }

  void _startSyncTimer(Duration delay) {
    _readSyncTimer?.cancel();
    _readSyncTimer = Timer(delay, () async {
      if (!mounted) return;
      if (!context.read<AppState>().syncsTool(NewsTool.config.id)) return;
      final success = await _syncSources();
      if (mounted && !success && _readSyncTimer?.isActive != true) {
        _startSyncTimer(_syncRetryDelay);
      }
    });
  }

  Future<void> _bootstrap() async {
    if (!mounted) return;
    final state = context.read<NewsState>();
    await state.init();
    if (!mounted) return;
    final appState = context.read<AppState>();
    _appState = appState;
    var syncing = appState.isSyncing;
    void onSyncChanged() {
      final finished = syncing && !appState.isSyncing;
      syncing = appState.isSyncing;
      if (!finished || !mounted) return;
      if (_syncWhenIdle) {
        _syncWhenIdle = false;
        unawaited(_syncOrRetry());
      } else if (!state.isLoading) {
        unawaited(state.reload());
      }
    }

    appState.addListener(onSyncChanged);
    onDispose(() => appState.removeListener(onSyncChanged));
    await _syncOrRetry();
  }

  Future<void> _syncOrRetry() async {
    if (!await _syncSources() && mounted && _readSyncTimer?.isActive != true) {
      _startSyncTimer(_syncRetryDelay);
    }
  }

  Future<bool> _syncSources() async {
    final appState = context.read<AppState>();
    final state = context.read<NewsState>();
    if (!appState.syncsTool(NewsTool.config.id)) return true;
    _readSyncDeadline = null;
    try {
      await state.flushReads();
      final sourcesBefore = {
        for (final source in state.sources) source.shortId: source.updatedAt,
      };
      final result = await appState.syncWithBackend([NewsSyncDelegate()]);
      if (result == null) {
        // Another sync is running and may have missed these reads.
        if (!appState.isSyncing) return false;
        _syncWhenIdle = true;
        return true;
      }
      final pulled = result['pulled'] ?? 0;
      final deleted = result['deleted'] ?? 0;
      if (!mounted || (pulled == 0 && deleted == 0)) return true;
      await state.reload();
      final sourcesChanged =
          state.sources.length != sourcesBefore.length ||
          state.sources.any(
            (source) => sourcesBefore[source.shortId] != source.updatedAt,
          );
      if (mounted && state.refreshOnOpen && sourcesChanged) {
        unawaited(state.refresh(only: state.enabledSources));
      }
      return true;
    } catch (e) {
      debugLog('[News] Sync failed: $e');
      return false;
    }
  }

  Future<void> _refresh() async {
    final state = context.read<NewsState>();
    if (state.isRefreshing) return;
    final l10n = AppLocalizations.of(context);
    await state.refresh();
    if (!mounted) return;
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.minScrollExtent);
    }
    unawaited(_syncSources());
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
    unawaited(state.markRead(article, immediate: true));
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NewsReaderPage(
          article: article,
          source: state.sourceFor(article.sourceShortId),
        ),
      ),
    );
    if (!mounted) return;
    _readSyncTimer?.cancel();
    await _syncOrRetry();
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
          focusNode: _actionsFocus,
          onPressed: () {
            final state = context.read<NewsState>();
            state.setHideRead(!state.hideRead);
          },
          tooltip: state.hideRead ? l10n.newsShowAll : l10n.newsUnreadOnly,
          icon: Icon(state.hideRead ? Icons.filter_alt : Icons.filter_alt_off),
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
          onPressed: () => NewsTextSizeSheet.show(context),
          tooltip: l10n.newsListTextSize,
          icon: const Icon(Icons.format_size),
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
                  child: NewsTextScale(
                    scale: state.listFontPercent / 100,
                    child: NewsList(
                      controller: _scrollController,
                      articles: state.articles,
                      sourceResolver: state.sourceFor,
                      markReadOnScroll: state.markReadOnScroll,
                      empty: NewsEmptyView(
                        hasSources: state.sources.isNotEmpty,
                        hideRead: state.hideRead,
                        onAddSources: _openPicker,
                        onRefresh: _refresh,
                        onShowAll: () =>
                            context.read<NewsState>().setHideRead(false),
                      ),
                      onRefresh: _refresh,
                      onRight: _actionsFocus.requestFocus,
                      onOpen: _openArticle,
                      onVisible: state.prefetchArticleImage,
                      onSeen: (article) {
                        if (mounted) unawaited(state.markRead(article));
                      },
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
