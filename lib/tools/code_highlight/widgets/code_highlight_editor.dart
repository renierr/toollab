import 'package:material_ui/material_ui.dart';
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
  List<int>? _shownTokens;
  int _lineCount = 1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Listened to, not watched: rebuilding on every keystroke made typing lag.
    final state = context.read<CodeHighlightState>();
    if (_state != state) {
      _state?.removeListener(_onStateChanged);
      _state = state;
      _state?.addListener(_onStateChanged);
    }

    if (_controller == null) {
      _controller = SyntaxHighlightEditingController(text: state.code ?? '');
      _showHighlight(state);
      _lineCount = _countLines(_controller!.text);
      _controller!.addListener(_onTextChanged);
    }
  }

  static int _countLines(String text) => '\n'.allMatches(text).length + 1;

  void _showHighlight(CodeHighlightState state) {
    if (identical(state.cachedTokens, _shownTokens)) return;
    _shownTokens = state.cachedTokens;
    _controller?.setHighlight(state.cachedTokens, state.cachedScopes);
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
    final controller = _controller;
    if (!mounted || state == null || controller == null) return;
    final code = state.code;
    if (code != null && code != controller.text) {
      // Changed from outside, e.g. a file was loaded.
      final selection = controller.selection;
      controller.text = code;
      controller.selection = selection.copyWith(
        baseOffset: selection.baseOffset.clamp(0, code.length),
        extentOffset: selection.extentOffset.clamp(0, code.length),
      );
    }
    _showHighlight(state);
  }

  void _onTextChanged() {
    final controller = _controller;
    final state = _state;
    if (controller == null || state == null || state.code == null) return;
    final lines = _countLines(controller.text);
    if (lines != _lineCount) setState(() => _lineCount = lines);
    if (controller.text == state.code) return;
    state.setCode(controller.text);
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
    final lineNumbersText = List.generate(
      _lineCount,
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
