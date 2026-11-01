import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Remote-control navigation for devices without a touch screen.
///
/// Flutter gives the arrow keys to the focused text field first, so up and down
/// move the caret and focus never leaves the field - with a D-pad that means
/// the user is stuck. While enabled this scope takes both keys back and moves
/// focus instead. Every other key keeps its default behaviour.
class TvNavigationScope extends StatefulWidget {
  final bool enabled;
  final Widget child;

  const TvNavigationScope({
    super.key,
    required this.enabled,
    required this.child,
  });

  @override
  State<TvNavigationScope> createState() => _TvNavigationScopeState();
}

class _TvNavigationScopeState extends State<TvNavigationScope> {
  static const Map<ShortcutActivator, Intent> _shortcuts = {
    SingleActivator(LogicalKeyboardKey.arrowUp): _MoveFocusIntent(
      TraversalDirection.up,
    ),
    SingleActivator(LogicalKeyboardKey.arrowDown): _MoveFocusIntent(
      TraversalDirection.down,
    ),
  };

  final _MoveFocusAction _moveFocus = _MoveFocusAction();

  @override
  Widget build(BuildContext context) {
    // The tree shape stays the same in both modes so toggling TV mode never
    // reparents the Navigator and drops page state.
    return Shortcuts(
      shortcuts: widget.enabled
          ? _shortcuts
          : const <ShortcutActivator, Intent>{},
      child: Actions(
        actions: widget.enabled
            ? <Type, Action<Intent>>{_MoveFocusIntent: _moveFocus}
            : const <Type, Action<Intent>>{},
        child: widget.child,
      ),
    );
  }
}

class _MoveFocusIntent extends Intent {
  final TraversalDirection direction;

  const _MoveFocusIntent(this.direction);
}

class _MoveFocusAction extends Action<_MoveFocusIntent> {
  @override
  void invoke(_MoveFocusIntent intent) {
    final primary = FocusManager.instance.primaryFocus;
    if (primary == null) return;
    if (primary.focusInDirection(intent.direction)) return;
    // Nothing lies that way (single field, or the edge of a grid). Only a text
    // field falls back to traversal order, so the remote can always get out.
    if (!_isEditingText(primary)) return;
    if (intent.direction == TraversalDirection.up) {
      primary.previousFocus();
    } else {
      primary.nextFocus();
    }
  }

  static bool _isEditingText(FocusNode node) {
    final context = node.context;
    return context != null &&
        context.findAncestorStateOfType<EditableTextState>() != null;
  }
}
