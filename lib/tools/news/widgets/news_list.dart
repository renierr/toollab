import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/services.dart';
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

  /// Right from a card or the footer, e.g. to reach the toolbar actions.
  final VoidCallback? onRight;

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
    this.onRight,
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
              onRight: onRight,
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
  final VoidCallback? onRight;

  const _TimelineList({
    this.controller,
    required this.articles,
    required this.sourceResolver,
    required this.markReadOnScroll,
    required this.onOpen,
    required this.onSeen,
    this.onVisible,
    required this.onRefresh,
    this.onRight,
  });

  @override
  State<_TimelineList> createState() => _TimelineListState();
}

class _TimelineListState extends State<_TimelineList> with DisposeCleanup {
  // Same arm distance as RefreshIndicator's pull from the top.
  static const double _pullViewportFraction = 0.25;
  static const Duration _wheelRelease = Duration(milliseconds: 350);

  static const Duration _moveDuration = Duration(milliseconds: 200);

  late ScrollController _controller;
  final ValueNotifier<int> _pulledPastEnd = ValueNotifier(0);
  final ValueNotifier<double> _bottomPull = ValueNotifier(0);
  final FocusNode _listFocus = FocusNode(
    debugLabel: 'NewsTimelineList',
    canRequestFocus: false,
    skipTraversal: true,
  );
  final FocusNode _footerFocus = FocusNode(debugLabel: 'NewsTimelineFooter');
  final Map<String, _ArticleFocusState> _rows = {};
  double _pullDistance = 0;
  bool _dragStartedAtBottom = false;
  bool _wheelPullSpent = false;
  bool _refreshing = false;
  int _moveSequence = 0;
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
      _listFocus.dispose();
      _footerFocus.dispose();
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
      if (mounted) unawaited(_refreshFromEnd());
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  Future<void> _refreshFromEnd() async {
    if (_refreshing) return;
    final hadFocus = _listFocus.hasFocus;
    setState(() => _refreshing = true);
    try {
      await widget.onRefresh();
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
    if (!mounted) return;
    // The new articles lay out after the page's jump; their real extents can
    // shift the old offset off the top.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || !_controller.hasClients) return;
    _controller.jumpTo(_controller.position.minScrollExtent);
    if (!hadFocus) return;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || widget.articles.isEmpty) return;
    _rows[widget.articles.first.guidKey]?.focusCard();
  }

  /// Up / Down step card to card and centre the target, so the remote never
  /// lands on a card at the viewport edge; past the last card is the footer.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final onRight = widget.onRight;
    if (key == LogicalKeyboardKey.arrowRight && onRight != null) {
      if (event is KeyDownEvent) onRight();
      return KeyEventResult.handled;
    }
    final direction = key == LogicalKeyboardKey.arrowDown
        ? 1
        : key == LogicalKeyboardKey.arrowUp
        ? -1
        : 0;
    if (direction == 0) return KeyEventResult.ignored;
    final articles = widget.articles;
    final int from;
    if (_footerFocus.hasPrimaryFocus) {
      from = articles.length;
    } else {
      final row = FocusManager.instance.primaryFocus?.context
          ?.findAncestorStateOfType<_ArticleFocusState>();
      if (row == null) return KeyEventResult.ignored;
      from = articles.indexWhere((a) => a.guidKey == row.widget.guidKey);
      if (from < 0) return KeyEventResult.ignored;
    }
    final to = from + direction;
    // Up from the first card leaves the list for the source filter.
    if (to < 0 || to > articles.length) return KeyEventResult.ignored;
    unawaited(_moveTo(to, direction));
    return KeyEventResult.handled;
  }

  FocusNode? _targetNode(int index) {
    if (index == widget.articles.length) {
      return _footerFocus.context == null ? null : _footerFocus;
    }
    final row = _rows[widget.articles[index].guidKey];
    return row != null && row.mounted ? row.cardNode : null;
  }

  Future<void> _moveTo(int index, int direction) async {
    final sequence = ++_moveSequence;
    // A card outside the built range has no focus node yet; scroll toward it
    // until the list builds it.
    for (var attempt = 0; attempt < 4; attempt++) {
      final node = _targetNode(index);
      final target = node?.context;
      if (node != null && target != null && target.mounted) {
        node.requestFocus();
        await _center(target);
        return;
      }
      if (!_controller.hasClients) return;
      final position = _controller.position;
      _controller.jumpTo(
        (position.pixels + direction * position.viewportDimension).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        ),
      );
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || sequence != _moveSequence) return;
    }
  }

  Future<void> _center(BuildContext target) {
    final box = target.findRenderObject();
    final viewport = _controller.hasClients
        ? _controller.position.viewportDimension
        : 0.0;
    // A card taller than the viewport would lose its top when centred.
    final tall = box is RenderBox && box.hasSize && box.size.height > viewport;
    return Scrollable.ensureVisible(
      target,
      alignment: tall ? 0 : 0.5,
      duration: _moveDuration,
      curve: Curves.easeOut,
    );
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
            child: Focus(
              focusNode: _listFocus,
              onKeyEvent: _onKey,
              child: ReadableScrollPadding(
                padding: const EdgeInsets.only(top: 4, bottom: 28),
                builder: (context, padding) => ListView.builder(
                  controller: _controller,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: padding,
                  scrollCacheExtent: const ScrollCacheExtent.pixels(500),
                  itemCount: entries.length + 1,
                  itemBuilder: (context, index) {
                    if (index == entries.length) {
                      return _RefreshFooter(
                        focusNode: _footerFocus,
                        markRead: widget.markReadOnScroll,
                        refreshing: _refreshing,
                        onPressed: _completeBottomPull,
                      );
                    }
                    final entry = entries[index];
                    final article = entry.article;
                    if (article == null) {
                      return _DateHeader(label: entry.header ?? '');
                    }
                    return _ArticleFocus(
                      key: ValueKey(article.guidKey),
                      guidKey: article.guidKey,
                      rows: _rows,
                      child: NewsReadTracker(
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
                      ),
                    );
                  },
                ),
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

/// Registers a card row so the list can focus it by article key.
class _ArticleFocus extends StatefulWidget {
  final String guidKey;
  final Map<String, _ArticleFocusState> rows;
  final Widget child;

  const _ArticleFocus({
    super.key,
    required this.guidKey,
    required this.rows,
    required this.child,
  });

  @override
  State<_ArticleFocus> createState() => _ArticleFocusState();
}

class _ArticleFocusState extends State<_ArticleFocus> {
  final FocusNode _node = FocusNode(
    debugLabel: 'NewsTimelineRow',
    canRequestFocus: false,
    skipTraversal: true,
  );

  @override
  void initState() {
    super.initState();
    widget.rows[widget.guidKey] = this;
  }

  @override
  void didUpdateWidget(covariant _ArticleFocus oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.guidKey != widget.guidKey) {
      _unregister(oldWidget.guidKey);
      widget.rows[widget.guidKey] = this;
    }
  }

  @override
  void dispose() {
    _unregister(widget.guidKey);
    _node.dispose();
    super.dispose();
  }

  void _unregister(String key) {
    if (widget.rows[key] == this) widget.rows.remove(key);
  }

  FocusNode? get cardNode {
    for (final node in _node.descendants) {
      if (node.canRequestFocus && !node.skipTraversal) return node;
    }
    return null;
  }

  void focusCard() => cardNode?.requestFocus();

  @override
  Widget build(BuildContext context) =>
      Focus(focusNode: _node, child: widget.child);
}

class _RefreshFooter extends StatelessWidget {
  final FocusNode focusNode;
  final bool markRead;
  final bool refreshing;
  final VoidCallback onPressed;

  const _RefreshFooter({
    required this.focusNode,
    required this.markRead,
    required this.refreshing,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Center(
        child: FilledButton.tonalIcon(
          focusNode: focusNode,
          // Stays enabled while refreshing so the remote keeps its focus here.
          onPressed: refreshing ? () {} : onPressed,
          icon: refreshing
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(markRead ? Icons.done_all : Icons.refresh),
          label: Text(
            markRead ? l10n.newsMarkReadAndRefresh : l10n.newsRefresh,
            textAlign: TextAlign.center,
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
