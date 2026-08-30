import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../engine/twenty48_direction.dart';

/// Turns swipes and arrow/WASD keys into [Twenty48Direction]s.
///
/// A swipe fires the moment it crosses [_threshold] rather than on release:
/// waiting for the finger to lift makes a slide feel a frame behind the player.
class Twenty48DirectionalInput extends StatefulWidget {
  final ValueChanged<Twenty48Direction> onDirection;
  final Widget child;

  const Twenty48DirectionalInput({
    super.key,
    required this.onDirection,
    required this.child,
  });

  @override
  State<Twenty48DirectionalInput> createState() =>
      _Twenty48DirectionalInputState();
}

class _Twenty48DirectionalInputState extends State<Twenty48DirectionalInput> {
  static const double _threshold = 24;

  /// Not const: [LogicalKeyboardKey] overrides `==`, which a constant map key
  /// may not do.
  static final Map<LogicalKeyboardKey, Twenty48Direction> _keyMap = {
    LogicalKeyboardKey.arrowUp: Twenty48Direction.up,
    LogicalKeyboardKey.arrowDown: Twenty48Direction.down,
    LogicalKeyboardKey.arrowLeft: Twenty48Direction.left,
    LogicalKeyboardKey.arrowRight: Twenty48Direction.right,
    LogicalKeyboardKey.keyW: Twenty48Direction.up,
    LogicalKeyboardKey.keyS: Twenty48Direction.down,
    LogicalKeyboardKey.keyA: Twenty48Direction.left,
    LogicalKeyboardKey.keyD: Twenty48Direction.right,
  };

  Offset _drag = Offset.zero;
  bool _fired = false;

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final direction = _keyMap[event.logicalKey];
    if (direction == null) return KeyEventResult.ignored;
    widget.onDirection(direction);
    return KeyEventResult.handled;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_fired) return;
    _drag += details.delta;
    if (_drag.distance < _threshold) return;
    _fired = true;
    final horizontal = _drag.dx.abs() > _drag.dy.abs();
    widget.onDirection(
      horizontal
          ? (_drag.dx > 0 ? Twenty48Direction.right : Twenty48Direction.left)
          : (_drag.dy > 0 ? Twenty48Direction.down : Twenty48Direction.up),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Autofocus so a desktop player can use the keyboard the instant the page
    // opens, without having to click the board first.
    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) {
          _drag = Offset.zero;
          _fired = false;
        },
        onPanUpdate: _onPanUpdate,
        child: widget.child,
      ),
    );
  }
}
