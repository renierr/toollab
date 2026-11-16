import 'package:flutter/widgets.dart';

/// Whether nothing specific has the focus: it fell back to the route scope
/// (or above) after the focused row went away.
bool fileManagerFocusLost(FocusNode list) {
  final primary = FocusManager.instance.primaryFocus;
  return primary == null || list.ancestors.contains(primary);
}

/// Scrolls a list of equally tall rows so row [index] is on screen; returns
/// whether it had to jump.
bool fileManagerRevealRow(ScrollController controller, int index, int count) {
  if (!controller.hasClients || count == 0) return false;
  final position = controller.position;
  final viewport = position.viewportDimension;
  final extent = (position.maxScrollExtent + viewport) / count;
  final top = index * extent;
  if (top >= position.pixels && top + extent <= position.pixels + viewport) {
    return false;
  }
  controller.jumpTo(
    (top - (viewport - extent) / 2).clamp(0.0, position.maxScrollExtent),
  );
  return true;
}

/// Focuses the first focusable under [list] whose context passes [match].
bool fileManagerFocusWhere(
  FocusNode list,
  bool Function(BuildContext context) match,
) {
  for (final node in list.traversalDescendants) {
    final context = node.context;
    if (!node.canRequestFocus || context == null || !match(context)) continue;
    node.requestFocus();
    return true;
  }
  return false;
}
