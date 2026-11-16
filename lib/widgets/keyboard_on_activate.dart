import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/providers/app_state.dart';

/// What the builder hands its text field: pass all three through.
typedef KeyboardGate = ({
  FocusNode focusNode,
  bool readOnly,
  VoidCallback onTap,
});

/// Keeps a text field read-only until OK / Enter or a tap, so a remote's
/// D-pad passing over it does not pop up the TV keyboard.
class KeyboardOnActivate extends StatefulWidget {
  /// Null follows [AppState.tvMode].
  final bool? enabled;
  final Widget Function(BuildContext context, KeyboardGate gate) builder;

  const KeyboardOnActivate({super.key, this.enabled, required this.builder});

  @override
  State<KeyboardOnActivate> createState() => _KeyboardOnActivateState();
}

class _KeyboardOnActivateState extends State<KeyboardOnActivate>
    with DisposeCleanup {
  final FocusNode _focus = FocusNode(debugLabel: 'KeyboardOnActivate');
  bool _editing = false;
  bool _gated = false;

  bool get _readOnly => _gated && !_editing;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChange);
    onDispose(() {
      _focus.removeListener(_onFocusChange);
      _focus.dispose();
    });
  }

  void _onFocusChange() {
    if (!_focus.hasFocus && _editing) setState(() => _editing = false);
  }

  void _startEditing() {
    if (!_readOnly) return;
    setState(() => _editing = true);
    _focus.requestFocus();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!_readOnly || event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.gameButtonA) {
      _startEditing();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    _gated =
        widget.enabled ??
        context.select<AppState?, bool>((s) => s?.tvMode ?? false);
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _onKey,
      child: widget.builder(context, (
        focusNode: _focus,
        readOnly: _readOnly,
        onTap: _startEditing,
      )),
    );
  }
}
