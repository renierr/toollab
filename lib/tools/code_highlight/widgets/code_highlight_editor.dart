import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../code_highlight_state.dart';
import '../code_highlight_engine.dart';

class SyntaxHighlightEditingController extends TextEditingController {
  final String language;

  SyntaxHighlightEditingController({super.text, required this.language});

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final theme = Theme.of(context);
    return CodeHighlightEngine.highlight(text, language, theme);
  }
}

class CodeHighlightEditor extends StatefulWidget {
  const CodeHighlightEditor({super.key});

  @override
  State<CodeHighlightEditor> createState() => _CodeHighlightEditorState();
}

class _CodeHighlightEditorState extends State<CodeHighlightEditor> {
  SyntaxHighlightEditingController? _controller;
  String? _lastLanguage;
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _controller?.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _updateControllerLanguage() {
    if (_controller == null) return;
    final state = context.read<CodeHighlightState>();
    final text = _controller!.text;
    final selection = _controller!.selection;

    _controller!.dispose();
    _controller = SyntaxHighlightEditingController(
      text: text,
      language: state.language,
    );
    _controller!.selection = selection;
    _controller!.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (_controller != null) {
      context.read<CodeHighlightState>().setCode(_controller!.text);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = context.watch<CodeHighlightState>();

    if (_lastLanguage != state.language) {
      _lastLanguage = state.language;
      if (_controller != null) {
        _updateControllerLanguage();
      } else {
        _controller = SyntaxHighlightEditingController(
          text: state.code ?? '',
          language: state.language,
        );
        _controller!.addListener(_onTextChanged);
      }
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
