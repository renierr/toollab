import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/chat_ai/chat_ai_state.dart';
import 'package:tool_lab/widgets/genai_status_banner.dart';

/// Inline on-device AI Q&A over an extracted block of text. Reuses the shared
/// [ChatAiState] engine (Gemini Nano) without touching its chat sessions.
class PdfTextAiQa extends StatefulWidget {
  final String documentText;

  const PdfTextAiQa({super.key, required this.documentText});

  @override
  State<PdfTextAiQa> createState() => _PdfTextAiQaState();
}

class _PdfTextAiQaState extends State<PdfTextAiQa> with DisposeCleanup {
  final TextEditingController _questionController = TextEditingController();
  bool _isAsking = false;
  String? _answer;
  String? _error;

  @override
  void initState() {
    super.initState();
    onDispose(_questionController.dispose);
  }

  Future<void> _ask() async {
    final question = _questionController.text.trim();
    if (question.isEmpty || _isAsking) return;

    final state = context.read<ChatAiState>();
    setState(() {
      _isAsking = true;
      _answer = null;
      _error = null;
    });
    try {
      final answer = await state.askAboutDocument(
        documentText: widget.documentText,
        question: question,
      );
      if (!mounted) return;
      setState(() => _answer = answer);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isAsking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final state = context.watch<ChatAiState>();
    final isTruncated =
        widget.documentText.length > ChatAiState.maxDocumentContextChars;

    final Widget answerArea;
    if (_isAsking) {
      answerArea = Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(l10n.pdfExtractTextThinking, style: theme.textTheme.bodyMedium),
        ],
      );
    } else if (_error != null) {
      answerArea = Text(
        _error!,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.error,
        ),
      );
    } else if (_answer == null) {
      answerArea = const SizedBox.shrink();
    } else {
      answerArea = Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxHeight: 220),
        decoration: BoxDecoration(
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
          borderRadius: BorderRadius.circular(12),
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.15),
        ),
        padding: const EdgeInsets.all(12.0),
        child: SingleChildScrollView(
          child: SelectableText(_answer!, style: theme.textTheme.bodyMedium),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        GenAiStatusBanner(
          status: state.featureStatus,
          onDownload: state.downloadModel,
        ),
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _questionController,
                      minLines: 1,
                      maxLines: 3,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _ask(),
                      decoration: InputDecoration(
                        hintText: l10n.pdfExtractTextAskHint,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _isAsking ? null : _ask,
                    icon: const Icon(Icons.send, size: 18),
                    label: Text(l10n.pdfExtractTextAskSend),
                  ),
                ],
              ),
              if (isTruncated)
                Padding(
                  padding: const EdgeInsets.only(top: 6.0),
                  child: Text(
                    l10n.pdfExtractTextTruncatedNote,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              answerArea,
            ],
          ),
        ),
      ],
    );
  }
}
