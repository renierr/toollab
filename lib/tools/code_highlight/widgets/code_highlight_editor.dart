import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/widgets/syntax_highlight_editing_controller.dart';
import '../code_highlight_state.dart';

class CodeHighlightEditor extends StatefulWidget {
  const CodeHighlightEditor({super.key});

  @override
  State<CodeHighlightEditor> createState() => _CodeHighlightEditorState();
}

class _CodeHighlightEditorState extends State<CodeHighlightEditor> {
  SyntaxHighlightEditingController? _controller;
  final ScrollController _scrollController = ScrollController();
  CodeHighlightState? _state;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = context.watch<CodeHighlightState>();
    if (_state != state) {
      _state?.removeListener(_onStateChanged);
      _state = state;
      _state?.addListener(_onStateChanged);
    }

    if (_controller == null) {
      _controller = SyntaxHighlightEditingController(text: state.code ?? '');
      _controller!.setHighlight(state.cachedTokens, state.cachedScopes);
      _controller!.addListener(_onTextChanged);
    } else if (state.code != null && state.code != _controller!.text) {
      // Keep editor in sync if text changed externally (e.g. file loaded)
      final selection = _controller!.selection;
      _controller!.text = state.code!;
      _controller!.selection = selection.copyWith(
        baseOffset: selection.baseOffset.clamp(0, state.code!.length),
        extentOffset: selection.extentOffset.clamp(0, state.code!.length),
      );
    }
  }

  @override
  void dispose() {
    _state?.removeListener(_onStateChanged);
    _controller?.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onStateChanged() {
    final state = _state;
    if (mounted && state != null) {
      _controller?.setHighlight(state.cachedTokens, state.cachedScopes);
    }
  }

  void _onTextChanged() {
    if (_controller != null && _state != null && _state!.code != null) {
      _state!.setCode(_controller!.text);
      setState(() {});
    }
  }

  void _insertTab() {
    if (_controller == null) return;
    final val = _controller!.value;
    final text = val.text;
    final selection = val.selection;

    final start = selection.start;
    final end = selection.end;

    if (start < 0) return;

    const tabString = '  ';
    final newText = text.replaceRange(start, end, tabString);
    final newSelection = TextSelection.collapsed(
      offset: start + tabString.length,
    );

    _controller!.value = TextEditingValue(
      text: newText,
      selection: newSelection,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final theme = Theme.of(context);
    final text = _controller!.text;
    final lineCount = '\n'.allMatches(text).length + 1;
    final lineNumbersText = List.generate(
      lineCount,
      (i) => '${i + 1}',
    ).join('\n');

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Scrollbar(
          controller: _scrollController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _scrollController,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.only(
                    top: 16,
                    bottom: 16,
                    left: 16,
                    right: 12,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.15,
                    ),
                    border: Border(
                      right: BorderSide(
                        color: theme.colorScheme.outlineVariant,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Text(
                    lineNumbersText,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                      height: 1.4,
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.5,
                      ),
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                Expanded(
                  child: CallbackShortcuts(
                    bindings: {
                      const SingleActivator(LogicalKeyboardKey.tab): _insertTab,
                    },
                    child: TextField(
                      controller: _controller!,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 14,
                        height: 1.4,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.only(
                          top: 16,
                          bottom: 16,
                          left: 16,
                          right: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
