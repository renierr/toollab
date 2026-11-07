import 'package:flutter/material.dart';

import '../news_article.dart';

class NewsReadTracker extends StatefulWidget {
  final NewsArticle article;
  final bool enabled;
  final VoidCallback onSeen;
  final Widget child;

  const NewsReadTracker({
    super.key,
    required this.article,
    required this.enabled,
    required this.onSeen,
    required this.child,
  });

  @override
  State<NewsReadTracker> createState() => _NewsReadTrackerState();
}

class _NewsReadTrackerState extends State<NewsReadTracker> {
  ScrollPosition? _position;
  bool _wasVisible = false;
  bool _marked = false;

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
      _position?.removeListener(_scheduleCheck);
      _position = position;
      _position?.addListener(_scheduleCheck);
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
      _scheduleCheck();
    }
  }

  @override
  void dispose() {
    _position?.removeListener(_scheduleCheck);
    super.dispose();
  }

  void _scheduleCheck() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _evaluate();
    });
  }

  void _evaluate() {
    if (!widget.enabled || widget.article.isRead || _marked) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return;
    final viewport = Scrollable.maybeOf(context)?.context.findRenderObject();
    if (viewport is! RenderBox || !viewport.hasSize) return;
    final top = box.localToGlobal(Offset.zero).dy;
    final bottom = top + box.size.height;
    final viewportTop = viewport.localToGlobal(Offset.zero).dy;
    final viewportBottom = viewportTop + viewport.size.height;
    if (bottom > viewportTop && top < viewportBottom) {
      _wasVisible = true;
    } else if (_wasVisible && bottom <= viewportTop) {
      _marked = true;
      widget.onSeen();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
