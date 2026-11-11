import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/providers/app_state.dart';
import 'package:tool_lab/widgets/readable_width.dart';

import '../models/x_post.dart';
import '../x_feed_state.dart';
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
  final ValueChanged<List<String>>? onSeen;

  const XTimelineView({
    super.key,
    required this.controller,
    this.applyFilters = false,
    this.header,
    this.focalPostId,
    this.emptyMessage,
    this.onSeen,
  });

  @override
  State<XTimelineView> createState() => _XTimelineViewState();
}

class _XTimelineViewState extends State<XTimelineView> with DisposeCleanup {
  static const double _maxWidth = 680;
  static const int _prefetchDistance = 5;
  static const Duration _seenDwell = Duration(seconds: 1);

  final ScrollController _scroll = ScrollController();
  final FocusNode _listFocus = FocusNode(
    debugLabel: 'XTimelineList',
    canRequestFocus: false,
    skipTraversal: true,
  );
  final Map<String, _PostRowState> _rows = {};
  List<XPost> _shown = const [];
  bool _tvMode = false;
  Timer? _seenTimer;
  late int _refreshCount = widget.controller.refreshCount;

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
      _showTop();
    }
    _scheduleSeenCheck();
  }

  /// A refresh brings new posts at the top, so start reading there.
  void _showTop() {
    if (_scroll.hasClients) _scroll.jumpTo(0);
    if (!_listFocus.hasFocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _shown.isEmpty) return;
      _rows[_shown.first.id]?.focusPost();
    });
  }

  /// Left / right step to the previous / next post on a keyboard. A TV keeps
  /// them for the rail and the media tiles.
  KeyEventResult _onListKey(FocusNode node, KeyEvent event) {
    if (_tvMode || event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final delta = key == LogicalKeyboardKey.arrowRight
        ? 1
        : key == LogicalKeyboardKey.arrowLeft
        ? -1
        : 0;
    if (delta == 0) return KeyEventResult.ignored;
    final row = FocusManager.instance.primaryFocus?.context
        ?.findAncestorStateOfType<_PostRowState>();
    if (row == null) return KeyEventResult.ignored;
    final index = _shown.indexWhere((p) => p.id == row.widget.postId);
    if (index < 0) return KeyEventResult.ignored;
    final target = index + delta;
    if (target >= 0 && target < _shown.length) {
      unawaited(_stepTo(_shown[target].id, delta));
    }
    return KeyEventResult.handled;
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
    } else if (notification is ScrollEndNotification) {
      _scheduleSeenCheck();
    }
    return false;
  }

  void _scheduleSeenCheck() {
    if (widget.onSeen == null) return;
    _seenTimer?.cancel();
    _seenTimer = Timer(_seenDwell, _collectSeen);
  }

  /// Posts at least half on screen once scrolling has settled count as seen.
  void _collectSeen() {
    final onSeen = widget.onSeen;
    if (onSeen == null || !mounted || !_scroll.hasClients) return;
    final viewport = _scroll.position.context.notificationContext
        ?.findRenderObject();
    if (viewport is! RenderBox || !viewport.attached || !viewport.hasSize) {
      return;
    }
    final bounds = Offset.zero & viewport.size;
    final seen = <String>[];
    for (final MapEntry(key: id, value: row) in _rows.entries) {
      if (!row.mounted) continue;
      final box = row.context.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) continue;
      final rect = MatrixUtils.transformRect(
        box.getTransformTo(viewport),
        Offset.zero & box.size,
      );
      final visible = rect.intersect(bounds);
      if (visible.width <= 0 || visible.height <= 0) continue;
      final needed = rect.height < bounds.height ? rect.height : bounds.height;
      if (visible.height >= needed / 2) seen.add(id);
    }
    if (seen.isNotEmpty) onSeen(seen);
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
              ReadableWidth(maxWidth: _maxWidth, child: header),
              SizedBox(height: 240, child: placeholder),
            ],
          );
        }

        final offset = header == null ? 0 : 1;
        return RefreshIndicator(
          onRefresh: controller.refresh,
          child: NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: Focus(
              focusNode: _listFocus,
              onKeyEvent: _onListKey,
              child: ReadableScrollPadding(
                maxWidth: _maxWidth,
                builder: (context, padding) => ListView.builder(
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
                    return _PostRow(
                      key: ValueKey(post.id),
                      postId: post.id,
                      rows: _rows,
                      child: XPostCard(
                        post: post,
                        autofocus: i == 0,
                        focal: post.id == widget.focalPostId,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A divided list row that registers itself so the view can tell which posts
/// are on screen.
class _PostRow extends StatefulWidget {
  final String postId;
  final Map<String, _PostRowState> rows;
  final Widget child;

  const _PostRow({
    super.key,
    required this.postId,
    required this.rows,
    required this.child,
  });

  @override
  State<_PostRow> createState() => _PostRowState();
}

class _PostRowState extends State<_PostRow> {
  final FocusNode _node = FocusNode(
    debugLabel: 'XTimelineRow',
    canRequestFocus: false,
    skipTraversal: true,
  );

  @override
  void initState() {
    super.initState();
    widget.rows[widget.postId] = this;
  }

  @override
  void didUpdateWidget(covariant _PostRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.postId != widget.postId) {
      _unregister(oldWidget.postId);
      widget.rows[widget.postId] = this;
    }
  }

  @override
  void dispose() {
    _unregister(widget.postId);
    _node.dispose();
    super.dispose();
  }

  void _unregister(String id) {
    if (widget.rows[id] == this) widget.rows.remove(id);
  }

  /// Focuses the card itself, the outermost focus stop of the row.
  void focusPost() {
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
    card?.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _node,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
              width: 0.5,
            ),
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
    if (controller.endReached) return const SizedBox(height: 48);
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}
