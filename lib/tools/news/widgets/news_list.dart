import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/readable_width.dart';

import '../news_article.dart';
import '../news_source.dart';
import '../news_time.dart';
import 'news_card.dart';
import 'news_read_tracker.dart';

class NewsList extends StatelessWidget {
  final ScrollController? controller;
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
    this.controller,
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
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: articles.isEmpty
          ? ReadableScrollPadding(
              padding: const EdgeInsets.all(24),
              builder: (context, padding) => ListView(
                controller: controller,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: padding,
                children: [empty],
              ),
            )
          : _TimelineList(
              controller: controller,
              articles: articles,
              sourceResolver: sourceResolver,
              markReadOnScroll: markReadOnScroll,
              onOpen: onOpen,
              onSeen: onSeen,
              onVisible: onVisible,
              onRefresh: onRefresh,
            ),
    );
  }
}

class _TimelineList extends StatefulWidget {
  final ScrollController? controller;
  final List<NewsArticle> articles;
  final NewsSource? Function(String sourceId) sourceResolver;
  final bool markReadOnScroll;
  final void Function(NewsArticle article) onOpen;
  final void Function(NewsArticle article) onSeen;
  final void Function(NewsArticle article)? onVisible;
  final Future<void> Function() onRefresh;

  const _TimelineList({
    this.controller,
    required this.articles,
    required this.sourceResolver,
    required this.markReadOnScroll,
    required this.onOpen,
    required this.onSeen,
    this.onVisible,
    required this.onRefresh,
  });

  @override
  State<_TimelineList> createState() => _TimelineListState();
}

class _TimelineListState extends State<_TimelineList> with DisposeCleanup {
  // Same arm distance as RefreshIndicator's pull from the top.
  static const double _pullViewportFraction = 0.25;
  static const Duration _wheelRelease = Duration(milliseconds: 350);

  late ScrollController _controller;
  final ValueNotifier<int> _pulledPastEnd = ValueNotifier(0);
  final ValueNotifier<double> _bottomPull = ValueNotifier(0);
  double _pullDistance = 0;
  bool _dragStartedAtBottom = false;
  bool _wheelPullSpent = false;
  Timer? _wheelReleaseTimer;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? ScrollController();
    onDispose(() {
      _wheelReleaseTimer?.cancel();
      if (widget.controller == null) _controller.dispose();
      _pulledPastEnd.dispose();
      _bottomPull.dispose();
    });
  }

  @override
  void didUpdateWidget(_TimelineList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      if (oldWidget.controller == null) _controller.dispose();
      _controller = widget.controller ?? ScrollController();
    }
  }

  void _addPull(double delta, double viewportExtent) {
    _pullDistance = (_pullDistance + delta).clamp(0, double.infinity);
    _bottomPull.value =
        (_pullDistance / (viewportExtent * _pullViewportFraction)).clamp(0, 1);
  }

  void _resetPull() {
    _pullDistance = 0;
    _bottomPull.value = 0;
  }

  void _completeBottomPull() {
    _resetPull();
    _pulledPastEnd.value++;
    // Let the trackers' post-frame read marks land before the refresh reloads.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(widget.onRefresh());
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || !_controller.hasClients) return;
    final position = _controller.position;
    final dy = event.scrollDelta.dy;
    if (dy <= 0 || position.extentAfter > 1) {
      _wheelReleaseTimer?.cancel();
      _wheelPullSpent = false;
      _resetPull();
      return;
    }
    // A wheel has no drag end, so a pause counts as letting go.
    _wheelReleaseTimer?.cancel();
    _wheelReleaseTimer = Timer(_wheelRelease, () {
      _wheelPullSpent = false;
      if (mounted) _resetPull();
    });
    if (_wheelPullSpent) return;
    _addPull(dy, position.viewportDimension);
    if (_bottomPull.value >= 1) {
      _wheelPullSpent = true;
      _completeBottomPull();
    }
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    final metrics = notification.metrics;
    switch (notification) {
      case ScrollStartNotification(:final dragDetails):
        _resetPull();
        _dragStartedAtBottom = dragDetails != null && metrics.extentAfter <= 1;
      case OverscrollNotification(:final dragDetails, :final overscroll)
          when dragDetails != null && _dragStartedAtBottom:
        _addPull(overscroll, metrics.viewportDimension);
      case ScrollUpdateNotification(:final dragDetails, :final scrollDelta)
          when dragDetails != null && _dragStartedAtBottom:
        if (metrics.pixels > metrics.maxScrollExtent) {
          // Bouncing physics overshoot instead of reporting overscroll.
          _pullDistance = 0;
          _addPull(
            metrics.pixels - metrics.maxScrollExtent,
            metrics.viewportDimension,
          );
        } else if ((scrollDelta ?? 0) < 0) {
          _addPull(scrollDelta!, metrics.viewportDimension);
        }
      case ScrollEndNotification():
        if (_bottomPull.value >= 1) {
          _completeBottomPull();
        } else {
          _resetPull();
        }
        _dragStartedAtBottom = false;
      default:
        break;
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
      child: Stack(
        children: [
          Listener(
            onPointerSignal: _onPointerSignal,
            child: ReadableScrollPadding(
              padding: const EdgeInsets.only(top: 4, bottom: 28),
              builder: (context, padding) => ListView.builder(
                controller: _controller,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: padding,
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
                    reachedEnd: _pulledPastEnd,
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
          ),
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: _BottomPullIndicator(progress: _bottomPull),
          ),
        ],
      ),
    );
  }
}

class _BottomPullIndicator extends StatelessWidget {
  final ValueListenable<double> progress;

  const _BottomPullIndicator({required this.progress});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: ValueListenableBuilder<double>(
          valueListenable: progress,
          builder: (context, value, _) => value == 0
              ? const SizedBox.shrink()
              : Material(
                  elevation: 3,
                  shape: const CircleBorder(),
                  color: Theme.of(context).colorScheme.surface,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(value: value),
                    ),
                  ),
                ),
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
