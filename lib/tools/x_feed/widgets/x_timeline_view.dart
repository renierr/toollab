import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/providers/app_state.dart';
import 'package:tool_lab/widgets/readable_width.dart';

import '../models/x_post.dart';
import '../x_feed_state.dart';
import '../x_keys.dart';
import '../x_layout.dart';
import '../x_timeline_controller.dart';
import 'x_error_view.dart';
import 'x_post_card.dart';

class XTimelineView extends StatefulWidget {
  final XTimelineController controller;

  /// Home tabs honour the hide-reposts / hide-replies settings.
  final bool applyFilters;
  final Widget? header;
  final String? focalPostId;
  final String? emptyMessage;

  /// Receives the ids of posts that stayed on screen for a moment.
  final ValueChanged<List<XPost>>? onSeen;

  /// Esc on a post, and right in TV mode: moves to the toolbar actions.
  final VoidCallback? onToolbar;

  const XTimelineView({
    super.key,
    required this.controller,
    this.applyFilters = false,
    this.header,
    this.focalPostId,
    this.emptyMessage,
    this.onSeen,
    this.onToolbar,
  });

  @override
  State<XTimelineView> createState() => _XTimelineViewState();
}

class _XTimelineViewState extends State<XTimelineView> with DisposeCleanup {
  static const int _prefetchDistance = 5;
  static const Duration _seenDwell = Duration(seconds: 1);

  /// How long a post scrolled out of view must have been on screen to count;
  /// a fling passes faster.
  static const Duration _passDwell = Duration(milliseconds: 500);
  static const Duration _passInterval = Duration(milliseconds: 100);

  final ScrollController _scroll = ScrollController();
  final FocusNode _listFocus = FocusNode(
    debugLabel: 'XTimelineList',
    canRequestFocus: false,
    skipTraversal: true,
  );
  final GlobalKey<RefreshIndicatorState> _refreshIndicator = GlobalKey();
  final Map<String, _PostRowState> _rows = {};
  List<XPost> _shown = const [];
  bool _tvMode = false;
  int _navigationSequence = 0;
  int _alignmentSequence = 0;
  bool _aligningPost = false;
  double? _nudgeTarget;
  Timer? _seenTimer;
  final Map<String, Duration> _visibleSince = {};
  Duration? _lastPassCheck;
  double? _lastPassPixels;
  late int _refreshCount = widget.controller.refreshCount;
  _Anchor? _anchor;
  double? _listWidth;
  bool _restoringAnchor = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    onDispose(() {
      _seenTimer?.cancel();
      widget.controller.removeListener(_onControllerChanged);
      _scroll.dispose();
      _listFocus.dispose();
    });
    unawaited(widget.controller.ensureLoaded());
  }

  @override
  void didUpdateWidget(covariant XTimelineView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
      _refreshCount = widget.controller.refreshCount;
      unawaited(widget.controller.ensureLoaded());
    }
  }

  void _onControllerChanged() {
    final count = widget.controller.refreshCount;
    if (count != _refreshCount) {
      _refreshCount = count;
      _visibleSince.clear();
      _showTop();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _trackPassing();
      _captureAnchor();
    });
    _scheduleSeenCheck();
  }

  /// A refresh rebuilds the list at the top (keyed by [_refreshCount]); the
  /// first new post takes over the focus.
  void _showTop() {
    if (!_listFocus.hasFocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _shown.isEmpty) return;
      _rows[_shown.first.id]?.focusPost();
    });
  }

  /// R reloads, Home goes to the first post, J / K and (keyboard only) right /
  /// left step post to post; a TV keeps left for the rail. Esc, and right on
  /// a TV, go to [XTimelineView.onToolbar].
  KeyEventResult _onListKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final row = FocusManager.instance.primaryFocus?.context
        ?.findAncestorStateOfType<_PostRowState>();
    if (row == null) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (HardwareKeyboard.instance.isShiftPressed &&
        XKeys.plain &&
        (key == LogicalKeyboardKey.arrowDown ||
            key == LogicalKeyboardKey.arrowUp)) {
      _nudge(key == LogicalKeyboardKey.arrowDown ? 1 : -1);
      return KeyEventResult.handled;
    }
    final sequence = ++_navigationSequence;
    if (key == LogicalKeyboardKey.arrowUp && _aligningPost) {
      _aligningPost = false;
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.offset);
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      final previousId = row.widget.postId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || sequence != _navigationSequence) return;
        final next = FocusManager.instance.primaryFocus?.context
            ?.findAncestorStateOfType<_PostRowState>();
        if (next == null || next == row || !next.cardHasPrimaryFocus) return;
        final from = _shown.indexWhere((post) => post.id == previousId);
        final to = _shown.indexWhere((post) => post.id == next.widget.postId);
        if (from < 0 || to <= from) return;
        _aligningPost = true;
        final alignment = ++_alignmentSequence;
        unawaited(
          Scrollable.ensureVisible(
            next.context,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          ).whenComplete(() {
            if (alignment == _alignmentSequence) _aligningPost = false;
          }),
        );
      });
    }
    if (!XKeys.plain) return KeyEventResult.ignored;
    if (key == LogicalKeyboardKey.keyR) {
      if (event is KeyDownEvent && !widget.controller.isLoading) {
        unawaited(_refreshIndicator.currentState?.show());
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.home) {
      unawaited(_toFirst());
      return KeyEventResult.handled;
    }
    final onToolbar = widget.onToolbar;
    if (onToolbar != null &&
        (key == LogicalKeyboardKey.escape ||
            _tvMode && key == LogicalKeyboardKey.arrowRight)) {
      if (event is KeyDownEvent) onToolbar();
      return KeyEventResult.handled;
    }
    final arrows = !_tvMode;
    final delta =
        key == LogicalKeyboardKey.keyJ ||
            arrows && key == LogicalKeyboardKey.arrowRight
        ? 1
        : key == LogicalKeyboardKey.keyK ||
              arrows && key == LogicalKeyboardKey.arrowLeft
        ? -1
        : 0;
    if (delta == 0) return KeyEventResult.ignored;
    final index = _shown.indexWhere((p) => p.id == row.widget.postId);
    if (index < 0) return KeyEventResult.ignored;
    final target = index + delta;
    if (target >= 0 && target < _shown.length) {
      unawaited(_stepTo(_shown[target].id, delta));
    }
    return KeyEventResult.handled;
  }

  /// Shift+Up/Down scrolls a short step for reading tall posts; held keys
  /// continue from the running animation's target.
  void _nudge(int direction) {
    if (!_scroll.hasClients) return;
    _aligningPost = false;
    final position = _scroll.position;
    final from = _nudgeTarget ?? position.pixels;
    final target = (from + direction * position.viewportDimension * 0.2).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    _nudgeTarget = target;
    unawaited(
      _scroll
          .animateTo(
            target,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          )
          .whenComplete(() {
            if (_nudgeTarget == target) _nudgeTarget = null;
          }),
    );
  }

  Future<void> _toFirst() async {
    if (!_scroll.hasClients || _shown.isEmpty) return;
    _scroll.jumpTo(_scroll.position.minScrollExtent);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted && _shown.isNotEmpty) _rows[_shown.first.id]?.focusPost();
  }

  Future<void> _stepTo(String postId, int direction) async {
    // A tall post can push its neighbour past the built range; scroll toward
    // it until the list has built it.
    for (var attempt = 0; attempt < 4; attempt++) {
      final row = _rows[postId];
      if (row != null && row.mounted) {
        row.focusPost();
        await Scrollable.ensureVisible(
          row.context,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
        return;
      }
      if (!_scroll.hasClients) return;
      final position = _scroll.position;
      _scroll.jumpTo(
        (position.pixels + direction * position.viewportDimension).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        ),
      );
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
    }
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    if (notification is ScrollStartNotification) {
      _seenTimer?.cancel();
    } else if (notification is ScrollUpdateNotification) {
      _trackPassing(throttled: true);
    } else if (notification is ScrollEndNotification) {
      _trackPassing();
      _captureAnchor();
      _scheduleSeenCheck();
    }
    return false;
  }

  /// Remembers the top post on screen, to keep it there when the width
  /// changes (rotation) and every post above it gets a new height.
  void _captureAnchor() {
    if (!mounted || _restoringAnchor) return;
    final layout = _rowLayout();
    if (layout == null) return;
    String? id;
    double? top;
    for (final MapEntry(key: rowId, value: rect) in layout.rects.entries) {
      if (rect.bottom <= layout.bounds.top) continue;
      if (top == null || rect.top < top) {
        id = rowId;
        top = rect.top;
      }
    }
    _anchor = id == null ? null : _Anchor(id, top!);
  }

  void _onWidthChanged(double width) {
    final previous = _listWidth;
    _listWidth = width;
    if (previous == null || previous == width) return;
    final anchor = _anchor;
    if (anchor == null) return;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(_restoreAnchor(anchor)),
    );
  }

  Future<void> _restoreAnchor(_Anchor anchor) async {
    if (_restoringAnchor) return;
    final target = _shown.indexWhere((post) => post.id == anchor.id);
    if (target < 0) return;
    final indexOf = {for (final (i, post) in _shown.indexed) post.id: i};
    _restoringAnchor = true;
    try {
      // The anchor may lie outside the built range at the old pixel offset;
      // page toward it until the list builds it.
      for (var attempt = 0; attempt < 10; attempt++) {
        if (!mounted || !_scroll.hasClients) return;
        final layout = _rowLayout();
        if (layout == null) return;
        final position = _scroll.position;
        final rect = layout.rects[anchor.id];
        final double next;
        if (rect != null) {
          next = position.pixels + rect.top - anchor.top;
        } else {
          final below = layout.rects.keys.any(
            (id) => (indexOf[id] ?? -1) > target,
          );
          next =
              position.pixels + (below ? -1 : 1) * position.viewportDimension;
        }
        _scroll.jumpTo(
          next.clamp(position.minScrollExtent, position.maxScrollExtent),
        );
        await WidgetsBinding.instance.endOfFrame;
        if (rect != null) return;
      }
    } finally {
      _restoringAnchor = false;
      _captureAnchor();
    }
  }

  void _scheduleSeenCheck() {
    if (widget.onSeen == null) return;
    _seenTimer?.cancel();
    _seenTimer = Timer(_seenDwell, _collectSeen);
  }

  /// Posts whose bottom is on screen once scrolling has settled count as seen.
  void _collectSeen() {
    final onSeen = widget.onSeen;
    if (onSeen == null || !mounted) return;
    final layout = _rowLayout();
    if (layout == null) return;
    final seen = [
      for (final MapEntry(key: id, value: rect) in layout.rects.entries)
        if (rect.bottom > layout.bounds.top &&
            rect.bottom <= layout.bounds.bottom + 1)
          id,
    ];
    if (seen.isNotEmpty) onSeen(_postsOf(seen));
  }

  /// A post scrolled past the top counts as seen when it was at least half
  /// visible for [_passDwell]; one leaving at the bottom was not read.
  void _trackPassing({bool throttled = false}) {
    final onSeen = widget.onSeen;
    if (onSeen == null || !mounted) return;
    final now = SchedulerBinding.instance.currentSystemFrameTimeStamp;
    final last = _lastPassCheck;
    if (throttled && last != null && now - last < _passInterval) return;
    _lastPassCheck = now;
    final layout = _rowLayout();
    if (layout == null) return;
    final pixels = _scroll.position.pixels;
    final movedDown = pixels > (_lastPassPixels ?? pixels);
    _lastPassPixels = pixels;
    final visible = layout.halfVisible;
    final passed = <String>[];
    _visibleSince.removeWhere((id, since) {
      if (visible.contains(id)) return false;
      final rect = layout.rects[id];
      // An unbuilt row left the built range in the direction of travel.
      final above = rect == null
          ? movedDown
          : rect.bottom <= layout.bounds.top + rect.height / 2;
      if (above && now - since >= _passDwell) passed.add(id);
      return true;
    });
    for (final id in visible) {
      _visibleSince.putIfAbsent(id, () => now);
    }
    if (passed.isNotEmpty) onSeen(_postsOf(passed));
  }

  List<XPost> _postsOf(Iterable<String> ids) {
    final wanted = ids.toSet();
    return [
      for (final post in _shown)
        if (wanted.contains(post.id)) post,
    ];
  }

  /// Viewport-relative rects of the built rows and the viewport bounds.
  _RowLayout? _rowLayout() {
    if (!_scroll.hasClients) return null;
    final viewport = _scroll.position.context.notificationContext
        ?.findRenderObject();
    if (viewport is! RenderBox || !viewport.attached || !viewport.hasSize) {
      return null;
    }
    final rects = <String, Rect>{};
    for (final MapEntry(key: id, value: row) in _rows.entries) {
      if (!row.mounted) continue;
      final box = row.context.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) continue;
      rects[id] = MatrixUtils.transformRect(
        box.getTransformTo(viewport),
        Offset.zero & box.size,
      );
    }
    return _RowLayout(Offset.zero & viewport.size, rects);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    _tvMode = context.select<AppState, bool>((s) => s.tvMode);
    final state = context.watch<XFeedState>();
    final controller = widget.controller;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final posts = widget.applyFilters
            ? state.filtered(controller.posts)
            : controller.posts;
        _shown = posts;
        final header = widget.header;
        final error = controller.error;

        if (posts.isEmpty) {
          final Widget placeholder;
          if (controller.isLoading || !controller.isLoaded && error == null) {
            placeholder = const Center(child: CircularProgressIndicator());
          } else if (error != null) {
            placeholder = Center(
              child: XErrorView(error: error, onRetry: controller.refresh),
            );
          } else {
            placeholder = Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  widget.emptyMessage ?? l10n.xFeedEmpty,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (header == null) return placeholder;
          return ListView(
            children: [
              ReadableWidth(maxWidth: XLayout.maxWidth, child: header),
              SizedBox(height: 240, child: placeholder),
            ],
          );
        }

        final offset = header == null ? 0 : 1;
        return RefreshIndicator(
          key: _refreshIndicator,
          onRefresh: controller.refresh,
          child: NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: Focus(
              focusNode: _listFocus,
              onKeyEvent: _onListKey,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  _onWidthChanged(constraints.maxWidth);
                  return ReadableScrollPadding(
                    maxWidth: XLayout.maxWidth,
                    // Jumping the old list to 0 lands below the top: its stale
                    // child offsets correct the position once the new posts lay out.
                    builder: (context, padding) => ListView.builder(
                      key: ValueKey(_refreshCount),
                      controller: _scroll,
                      padding: padding,
                      itemCount: posts.length + offset + 1,
                      itemBuilder: (context, index) {
                        if (index < offset) return header;
                        final i = index - offset;
                        if (i == posts.length) {
                          return _Footer(controller: controller);
                        }
                        if (i >= posts.length - _prefetchDistance &&
                            error == null) {
                          WidgetsBinding.instance.addPostFrameCallback(
                            (_) => unawaited(controller.loadMore()),
                          );
                        }
                        final post = posts[i];
                        final focal = post.id == widget.focalPostId;
                        // A thread page's replies hang off the focal post as
                        // siblings, so the line stops there.
                        final above =
                            i > 0 &&
                            post.replyToId == posts[i - 1].id &&
                            posts[i - 1].id != widget.focalPostId;
                        final below =
                            !focal &&
                            i + 1 < posts.length &&
                            posts[i + 1].replyToId == post.id;
                        return _PostRow(
                          key: ValueKey(post.id),
                          postId: post.id,
                          rows: _rows,
                          divider: !below,
                          child: XPostCard(
                            post: post,
                            autofocus: i == 0,
                            focal: focal,
                            threadAbove: above,
                            threadBelow: below,
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Anchor {
  final String id;

  /// Offset of the post's top from the viewport's top.
  final double top;

  const _Anchor(this.id, this.top);
}

/// A divided list row that registers itself so the view can tell which posts
/// are on screen.
class _PostRow extends StatefulWidget {
  final String postId;
  final Map<String, _PostRowState> rows;
  final bool divider;
  final Widget child;

  const _PostRow({
    super.key,
    required this.postId,
    required this.rows,
    required this.divider,
    required this.child,
  });

  @override
  State<_PostRow> createState() => _PostRowState();
}

class _PostRowState extends State<_PostRow> with DisposeCleanup {
  final FocusNode _node = FocusNode(
    debugLabel: 'XTimelineRow',
    canRequestFocus: false,
    skipTraversal: true,
  );

  @override
  void initState() {
    super.initState();
    widget.rows[widget.postId] = this;
    onDispose(() {
      _unregister(widget.postId);
      _node.dispose();
    });
  }

  @override
  void didUpdateWidget(covariant _PostRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.postId != widget.postId) {
      _unregister(oldWidget.postId);
      widget.rows[widget.postId] = this;
    }
  }

  void _unregister(String id) {
    if (widget.rows[id] == this) widget.rows.remove(id);
  }

  /// Focuses the card itself, the outermost focus stop of the row.
  FocusNode? get _cardNode {
    FocusNode? card;
    var cardDepth = 0;
    for (final node in _node.descendants) {
      if (!node.canRequestFocus || node.skipTraversal) continue;
      final depth = node.ancestors.length;
      if (card == null || depth < cardDepth) {
        card = node;
        cardDepth = depth;
      }
    }
    return card;
  }

  bool get cardHasPrimaryFocus => _cardNode?.hasPrimaryFocus ?? false;

  void focusPost() => _cardNode?.requestFocus();

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _node,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: widget.divider
                ? BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    width: 0.5,
                  )
                : BorderSide.none,
          ),
        ),
        child: widget.child,
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  final XTimelineController controller;

  const _Footer({required this.controller});

  @override
  Widget build(BuildContext context) {
    final error = controller.error;
    if (error != null) {
      return XErrorView(
        error: error,
        onRetry: controller.loadMore,
        compact: true,
      );
    }
    if (controller.endReached) {
      final l10n = AppLocalizations.of(context);
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.xFeedNoMorePosts,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (controller.canRetryEnd) ...[
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: controller.retryEnd,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.xFeedLoadMoreAgain),
              ),
            ],
          ],
        ),
      );
    }
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _RowLayout {
  final Rect bounds;
  final Map<String, Rect> rects;

  const _RowLayout(this.bounds, this.rects);

  /// Ids of the rows at least half on screen (or filling half of it).
  Set<String> get halfVisible => {
    for (final MapEntry(key: id, value: rect) in rects.entries)
      if (_isHalfVisible(rect)) id,
  };

  bool _isHalfVisible(Rect rect) {
    final shown = rect.intersect(bounds);
    if (shown.width <= 0 || shown.height <= 0) return false;
    final needed = rect.height < bounds.height ? rect.height : bounds.height;
    return shown.height >= needed / 2;
  }
}
