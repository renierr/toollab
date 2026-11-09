import 'package:flutter/material.dart';
import 'package:tool_lab/widgets/readable_width.dart';

import 'depot_section_nav.dart';

class DepotSection<T> extends DepotSectionLink<T> {
  final Widget child;

  const DepotSection({
    required super.id,
    required super.label,
    required super.icon,
    required this.child,
  });
}

/// A pull-to-refresh column of sections under a pinned row of jump links
/// that follows the section in view.
class DepotSectionScrollView<T> extends StatefulWidget {
  final List<Widget> header;
  final List<DepotSection<T>> sections;

  /// Lazy content after the last section, such as a long list.
  final List<Widget> slivers;
  final RefreshCallback onRefresh;
  final EdgeInsetsGeometry padding;
  final double spacing;

  const DepotSectionScrollView({
    super.key,
    this.header = const [],
    required this.sections,
    this.slivers = const [],
    required this.onRefresh,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 24),
    this.spacing = 24,
  });

  @override
  State<DepotSectionScrollView<T>> createState() =>
      _DepotSectionScrollViewState<T>();
}

class _DepotSectionScrollViewState<T> extends State<DepotSectionScrollView<T>> {
  // How far below the viewport top a section still counts as the current one.
  static const double _activeSlack = 24;

  final Map<T, GlobalKey> _keys = {};
  T? _active;
  bool _jumping = false;

  GlobalKey _keyOf(T id) => _keys.putIfAbsent(id, GlobalKey.new);

  Future<void> _jumpTo(T id) async {
    final target = _keys[id]?.currentContext;
    if (target == null) return;
    setState(() => _active = id);
    _jumping = true;
    try {
      await Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    } finally {
      _jumping = false;
    }
  }

  bool _onScroll(ScrollNotification notification) {
    if (_jumping ||
        notification.depth != 0 ||
        notification is! ScrollUpdateNotification) {
      return false;
    }
    final viewport = notification.context?.findRenderObject();
    if (viewport is! RenderBox) return false;
    final viewportTop = viewport.localToGlobal(Offset.zero).dy;
    final atEnd = notification.metrics.extentAfter < 1;
    T? current;
    for (final section in widget.sections) {
      final box = _keys[section.id]?.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.attached) continue;
      final top = box.localToGlobal(Offset.zero).dy - viewportTop;
      if (atEnd || top <= _activeSlack || current == null) current = section.id;
    }
    if (current != null && current != _active) {
      setState(() => _active = current);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final sections = widget.sections;
    final active = sections.any((s) => s.id == _active)
        ? _active
        : sections.firstOrNull?.id;

    return ReadableScrollPadding(
      builder: (context, inset) => Column(
        children: [
          if (sections.length > 1)
            Padding(
              padding: inset + const EdgeInsets.symmetric(vertical: 4),
              child: DepotSectionNav<T>(
                links: sections,
                active: active,
                onSelect: _jumpTo,
              ),
            ),
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: _onScroll,
              child: RefreshIndicator(
                onRefresh: widget.onRefresh,
                // A Column, not a lazy list: a jump target below the fold
                // must be built for ensureVisible to find it.
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: widget.padding.add(inset),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ...widget.header,
                            for (final (index, section)
                                in sections.indexed) ...[
                              if (index > 0 && widget.spacing > 0)
                                SizedBox(height: widget.spacing),
                              KeyedSubtree(
                                key: _keyOf(section.id),
                                child: section.child,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    for (final sliver in widget.slivers)
                      SliverPadding(padding: inset, sliver: sliver),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
