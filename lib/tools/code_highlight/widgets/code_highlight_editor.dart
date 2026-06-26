import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../code_highlight_state.dart';
import '../code_highlight_engine.dart';

class SyntaxHighlightEditingController extends TextEditingController {
  SyntaxHighlightEditingController({super.text});

  void updateHighlight() {
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final state = Provider.of<CodeHighlightState>(context, listen: false);
    final theme = Theme.of(context);
    final scopes = state.cachedScopes;
    final tokens = state.cachedTokens;

    if (tokens.isEmpty || text.isEmpty) {
      return TextSpan(
        text: text,
        style: TextStyle(
          color: theme.colorScheme.onSurface,
          fontFamily: 'monospace',
        ),
      );
    }

    final List<TextSpan> children = [];
    int lastOffset = 0;

    for (int i = 0; i < tokens.length; i += 3) {
      final start = tokens[i];
      final length = tokens[i + 1];
      final scopeId = tokens[i + 2];

      if (start > text.length) break;
      final end = (start + length).clamp(0, text.length);

      if (start > lastOffset) {
        children.add(TextSpan(text: text.substring(lastOffset, start)));
      }

      final tokenText = text.substring(start, end);
      if (scopeId < scopes.length) {
        final scope = scopes[scopeId];
        final tokenStyle = TextMateEngine.getScopeStyle(scope, theme);
        children.add(TextSpan(text: tokenText, style: tokenStyle));
      } else {
        children.add(TextSpan(text: tokenText));
      }
      lastOffset = end;
    }

    if (lastOffset < text.length) {
      children.add(TextSpan(text: text.substring(lastOffset)));
    }

    return TextSpan(
      children: children,
      style: TextStyle(
        color: theme.colorScheme.onSurface,
        fontFamily: 'monospace',
      ),
    );
  }
}

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
    final state = Provider.of<CodeHighlightState>(context);
    if (_state != state) {
      _state?.removeListener(_onStateChanged);
      _state = state;
      _state?.addListener(_onStateChanged);
    }

    if (_controller == null) {
      _controller = SyntaxHighlightEditingController(text: state.code ?? '');
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
    if (mounted) {
      _controller?.updateHighlight();
    }
  }

  void _onTextChanged() {
    if (_controller != null && _state != null && _state!.code != null) {
      _state!.setCode(_controller!.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final theme = Theme.of(context);

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
                contentPadding: EdgeInsets.all(16),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
