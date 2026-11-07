import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent, ScrollDirection;
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/readable_width.dart';

import '../news_article.dart';
import '../news_source.dart';
import '../news_time.dart';
import 'news_card.dart';
import 'news_read_tracker.dart';

class NewsList extends StatelessWidget {
  final List<NewsArticle> articles;
  final NewsSource? Function(String sourceId) sourceResolver;
  final bool markReadOnScroll;
  final Widget empty;
  final Future<void> Function() onRefresh;
  final void Function(NewsArticle article) onOpen;
  final void Function(NewsArticle article) onSeen;
  final void Function(NewsArticle article)? onVisible;

  const NewsList({
    super.key,
    required this.articles,
    required this.sourceResolver,
    required this.markReadOnScroll,
    required this.empty,
    required this.onRefresh,
    required this.onOpen,
    required this.onSeen,
    this.onVisible,
  });

  @override
  Widget build(BuildContext context) {
    return ReadableWidth(
      maxWidth: 900,
      child: RefreshIndicator(
        onRefresh: onRefresh,
        child: articles.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: [empty],
              )
            : _TimelineList(
                articles: articles,
                sourceResolver: sourceResolver,
                markReadOnScroll: markReadOnScroll,
                onOpen: onOpen,
                onSeen: onSeen,
                onVisible: onVisible,
              ),
      ),
    );
  }
}

class _TimelineList extends StatefulWidget {
  final List<NewsArticle> articles;
  final NewsSource? Function(String sourceId) sourceResolver;
  final bool markReadOnScroll;
  final void Function(NewsArticle article) onOpen;
  final void Function(NewsArticle article) onSeen;
  final void Function(NewsArticle article)? onVisible;

  const _TimelineList({
    required this.articles,
    required this.sourceResolver,
    required this.markReadOnScroll,
    required this.onOpen,
    required this.onSeen,
    this.onVisible,
  });

  @override
  State<_TimelineList> createState() => _TimelineListState();
}

class _TimelineListState extends State<_TimelineList> with DisposeCleanup {
  static const _endPause = Duration(seconds: 1);
  final ScrollController _controller = ScrollController();
  final ValueNotifier<int> _reachedEnd = ValueNotifier(0);
  Timer? _endTimer;
  bool _scrollingDown = false;

  @override
  void initState() {
    super.initState();
    onDispose(() {
      _endTimer?.cancel();
      _controller.dispose();
      _reachedEnd.dispose();
    });
  }

  void _scheduleEndCheck() {
    _endTimer?.cancel();
    if (!widget.markReadOnScroll) return;
    _endTimer = Timer(_endPause, () {
      if (!mounted || !widget.markReadOnScroll || !_controller.hasClients) {
        return;
      }
      final position = _controller.position;
      if (position.extentAfter <= 1 && !position.isScrollingNotifier.value) {
        _reachedEnd.value++;
      }
    });
  }

  @override
  void didUpdateWidget(_TimelineList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.markReadOnScroll) _endTimer?.cancel();
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    _endTimer?.cancel();
    if (event.scrollDelta.dy > 0 &&
        _controller.hasClients &&
        _controller.position.extentAfter <= 1) {
      _scheduleEndCheck();
    }
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    if (notification is UserScrollNotification) {
      if (notification.direction == ScrollDirection.reverse) {
        _scrollingDown = true;
      } else if (notification.direction == ScrollDirection.forward) {
        _scrollingDown = false;
      }
    } else if (notification is ScrollUpdateNotification) {
      _endTimer?.cancel();
      if (notification.dragDetails != null &&
          (notification.scrollDelta ?? 0) > 0) {
        _scrollingDown = true;
      }
    } else if (notification is OverscrollNotification) {
      _endTimer?.cancel();
      if (notification.dragDetails != null && notification.overscroll > 0) {
        _scrollingDown = true;
      }
    } else if (notification is ScrollEndNotification) {
      if (_scrollingDown && notification.metrics.extentAfter <= 1) {
        _scheduleEndCheck();
      }
      _scrollingDown = false;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final now = DateTime.now();
    final entries = <_TimelineEntry>[];
    DateTime? previousDay;
    for (final article in widget.articles) {
      final date = DateTime.fromMillisecondsSinceEpoch(article.publishedAt);
      final day = DateTime(date.year, date.month, date.day);
      if (previousDay == null || day != previousDay) {
        entries.add(
          _TimelineEntry.header(newsDayLabel(l10n, locale, date, now)),
        );
        previousDay = day;
      }
      entries.add(_TimelineEntry.article(article));
    }

    return NotificationListener<ScrollNotification>(
      onNotification: _onScrollNotification,
      child: Listener(
        onPointerSignal: _onPointerSignal,
        child: ListView.builder(
          controller: _controller,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: 4, bottom: 28),
          scrollCacheExtent: const ScrollCacheExtent.pixels(500),
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final entry = entries[index];
            final article = entry.article;
            if (article == null) {
              return _DateHeader(label: entry.header ?? '');
            }
            return NewsReadTracker(
              key: ValueKey(article.guidKey),
              article: article,
              enabled: widget.markReadOnScroll,
              reachedEnd: _reachedEnd,
              onSeen: () => widget.onSeen(article),
              onVisible: () => widget.onVisible?.call(article),
              child: NewsCard(
                article: article,
                source: widget.sourceResolver(article.sourceShortId),
                onTap: () => widget.onOpen(article),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TimelineEntry {
  final String? header;
  final NewsArticle? article;

  const _TimelineEntry.header(this.header) : article = null;
  const _TimelineEntry.article(this.article) : header = null;
}

class _DateHeader extends StatelessWidget {
  final String label;

  const _DateHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Divider(
              height: 1,
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
