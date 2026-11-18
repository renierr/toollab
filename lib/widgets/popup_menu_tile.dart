import 'package:material_ui/material_ui.dart';
import 'package:flutter/semantics.dart';

/// [PopupMenuItem] child that leaves key focus on the item, which owns the tap.
class PopupMenuTile extends StatelessWidget {
  final Widget? leading;
  final Widget title;
  final Widget? trailing;
  final bool? dense;

  const PopupMenuTile({
    super.key,
    this.leading,
    required this.title,
    this.trailing,
    this.dense,
  });

  @override
  Widget build(BuildContext context) {
    return ExcludeFocus(
      child: ListTile(
        dense: dense,
        contentPadding: EdgeInsets.zero,
        leading: leading,
        title: title,
        trailing: trailing,
      ),
    );
  }
}

/// [CheckedPopupMenuItem] whose inner [ListTile] cannot steal key focus.
class CheckedPopupMenuTile<T> extends CheckedPopupMenuItem<T> {
  const CheckedPopupMenuTile({
    super.key,
    super.value,
    super.checked,
    super.enabled,
    super.padding,
    super.height,
    super.labelTextStyle,
    super.mouseCursor,
    super.child,
    super.onTap,
  });

  @override
  PopupMenuItemState<T, CheckedPopupMenuItem<T>> createState() =>
      _CheckedPopupMenuTileState<T>();
}

class _CheckedPopupMenuTileState<T>
    extends PopupMenuItemState<T, CheckedPopupMenuItem<T>>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 150),
    vsync: this,
    value: widget.checked ? 1.0 : 0.0,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void handleTap() {
    widget.checked ? _controller.reverse() : _controller.forward();
    super.handleTap();
  }

  @override
  Widget buildSemantics({required Widget child}) {
    return Semantics(
      role: SemanticsRole.menuItemCheckbox,
      enabled: widget.enabled,
      checked: widget.checked,
      button: true,
      child: child,
    );
  }

  @override
  Widget buildChild() {
    return IgnorePointer(
      child: ExcludeFocus(
        child: ListTile(
          enabled: widget.enabled,
          contentPadding: EdgeInsets.zero,
          leading: FadeTransition(
            opacity: _controller,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) =>
                  Icon(_controller.isDismissed ? null : Icons.done),
            ),
          ),
          title: widget.child,
        ),
      ),
    );
  }
}
