import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

class OverviewSearchField extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  /// On a TV focus alone must not open the keyboard, or the remote's Down
  /// lands in it; OK opens it instead.
  final bool keyboardOnActivate;

  const OverviewSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.keyboardOnActivate = false,
  });

  @override
  State<OverviewSearchField> createState() => _OverviewSearchFieldState();
}

class _OverviewSearchFieldState extends State<OverviewSearchField>
    with DisposeCleanup {
  final FocusNode _focus = FocusNode(debugLabel: 'OverviewSearch');
  bool _editing = false;

  bool get _readOnly => widget.keyboardOnActivate && !_editing;

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

  void _clear() {
    widget.controller.clear();
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _onKey,
      child: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) => TextField(
          controller: widget.controller,
          focusNode: _focus,
          readOnly: _readOnly,
          onTap: _startEditing,
          onChanged: widget.onChanged,
          decoration: InputDecoration(
            hintText: l10n.coreOverviewSearchHint,
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: widget.controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: _clear,
                  )
                : null,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }
}
