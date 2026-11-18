import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/widgets/tool_chip.dart';

class DepotSectionLink<T> {
  final T id;
  final String label;
  final IconData? icon;

  const DepotSectionLink({required this.id, required this.label, this.icon});
}

/// A scrolling row of jump links to the sections of a long view.
class DepotSectionNav<T> extends StatefulWidget {
  final List<DepotSectionLink<T>> links;
  final T? active;
  final ValueChanged<T> onSelect;

  const DepotSectionNav({
    super.key,
    required this.links,
    required this.active,
    required this.onSelect,
  });

  /// Focuses the active chip of the row shown in [context]'s route. Down from
  /// the tabs needs it: directional focus skips a row that does not lie
  /// under the focused tab.
  static bool focusActive(BuildContext context) {
    final route = ModalRoute.of(context);
    for (final node in FocusManager.instance.rootScope.descendants) {
      final nav = node.context;
      if (node is! _NavNode || nav == null || !nav.mounted) continue;
      if (ModalRoute.of(nav) != route) continue;
      final chips = [
        for (final chip in node.traversalDescendants)
          if (chip.canRequestFocus && chip.context != null) chip,
      ];
      if (chips.isEmpty) continue;
      final active = chips.firstWhere(
        (chip) =>
            chip.context!.findAncestorWidgetOfExactType<ToolChip>()?.selected ??
            false,
        orElse: () => chips.first,
      );
      active.requestFocus();
      unawaited(Scrollable.ensureVisible(active.context!));
      return true;
    }
    return false;
  }

  @override
  State<DepotSectionNav<T>> createState() => _DepotSectionNavState<T>();
}

class _NavNode extends FocusNode {
  _NavNode()
    : super(
        debugLabel: 'DepotSectionNav',
        canRequestFocus: false,
        skipTraversal: true,
      );
}

class _DepotSectionNavState<T> extends State<DepotSectionNav<T>>
    with DisposeCleanup {
  final _NavNode _node = _NavNode();

  @override
  void initState() {
    super.initState();
    onDispose(_node.dispose);
  }

  @override
  Widget build(BuildContext context) => Focus(
    focusNode: _node,
    child: SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: widget.links.length,
        separatorBuilder: (_, _) => const SizedBox(width: 4),
        itemBuilder: (context, index) {
          final link = widget.links[index];
          return Center(
            child: ToolChip(
              icon: link.icon,
              label: link.label,
              selected: link.id == widget.active,
              onTap: () => widget.onSelect(link.id),
            ),
          );
        },
      ),
    ),
  );
}
