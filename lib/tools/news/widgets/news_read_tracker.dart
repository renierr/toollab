import 'package:flutter/material.dart';

import '../news_article.dart';

class NewsReadTracker extends StatefulWidget {
  final NewsArticle article;
  final bool enabled;
  final VoidCallback onSeen;
  final VoidCallback? onVisible;
  final Widget child;

  const NewsReadTracker({
    super.key,
    required this.article,
    required this.enabled,
    required this.onSeen,
    this.onVisible,
    required this.child,
  });

  @override
  State<NewsReadTracker> createState() => _NewsReadTrackerState();
}

class _NewsReadTrackerState extends State<NewsReadTracker> {
  ScrollPosition? _position;
  bool _wasVisible = false;
  bool _marked = false;
  bool _checkScheduled = false;
  bool _visibilityReported = false;
  double? _measuredPixels;
  double? _measuredBottom;
  double? _viewportTop;

  @override
  void initState() {
    super.initState();
    _scheduleCheck();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    if (!identical(position, _position)) {
      _position?.removeListener(_onScroll);
      _position = position;
      _position?.addListener(_onScroll);
      _scheduleCheck();
    }
  }

  @override
  void didUpdateWidget(NewsReadTracker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled ||
        oldWidget.article.id != widget.article.id ||
        oldWidget.article.isRead != widget.article.isRead) {
      _wasVisible = false;
      _marked = false;
      _measuredPixels = null;
      _scheduleCheck();
    }
    if (oldWidget.article.id != widget.article.id) {
      _visibilityReported = false;
    }
  }

  @override
  void dispose() {
    _position?.removeListener(_onScroll);
    super.dispose();
  }

  void _scheduleCheck() {
    if (_checkScheduled) return;
    _checkScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkScheduled = false;
      if (mounted) _evaluate();
    });
  }

  void _onScroll() {
    final position = _position;
    final pixels = _measuredPixels;
    final bottom = _measuredBottom;
    final viewportTop = _viewportTop;
    if (widget.enabled &&
        !widget.article.isRead &&
        !_marked &&
        _wasVisible &&
        position != null &&
        pixels != null &&
        bottom != null &&
        viewportTop != null &&
        bottom - (position.pixels - pixels) <= viewportTop) {
      _markSeen();
    }
    _scheduleCheck();
  }

  void _markSeen() {
    if (_marked) return;
    _marked = true;
    final onSeen = widget.onSeen;
    WidgetsBinding.instance.addPostFrameCallback((_) => onSeen());
    WidgetsBinding.instance.scheduleFrame();
  }

  void _evaluate() {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return;
    final viewport = Scrollable.maybeOf(context)?.context.findRenderObject();
    if (viewport is! RenderBox || !viewport.hasSize) return;
    final top = box.localToGlobal(Offset.zero).dy;
    final bottom = top + box.size.height;
    final viewportTop = viewport.localToGlobal(Offset.zero).dy;
    final viewportBottom = viewportTop + viewport.size.height;
    _measuredPixels = _position?.pixels;
    _measuredBottom = bottom;
    _viewportTop = viewportTop;
    if (bottom > viewportTop && top < viewportBottom) {
      _wasVisible = true;
      if (!_visibilityReported) {
        _visibilityReported = true;
        widget.onVisible?.call();
      }
    } else if (widget.enabled &&
        !widget.article.isRead &&
        !_marked &&
        _wasVisible &&
        bottom <= viewportTop) {
      _markSeen();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
