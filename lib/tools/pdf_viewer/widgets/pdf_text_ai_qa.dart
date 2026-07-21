import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/helpers/text_analysis_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/chat_ai/chat_ai_state.dart';
import 'package:tool_lab/widgets/genai_status_banner.dart';

enum _ResultKind { ask, summary, keywords }

/// Inline text-intelligence section over an extracted block of text. Uses the
/// on-device LLM ([ChatAiState]) when available, and always offers offline
/// extractive tools (summary, keywords, passage answers) via
/// [TextAnalysisHelper] so it works on every platform.
class PdfTextAiQa extends StatefulWidget {
  final String documentText;

  const PdfTextAiQa({super.key, required this.documentText});

  @override
  State<PdfTextAiQa> createState() => _PdfTextAiQaState();
}

class _PdfTextAiQaState extends State<PdfTextAiQa> with DisposeCleanup {
  final TextEditingController _questionController = TextEditingController();
  bool _isBusy = false;
  String? _result;
  _ResultKind? _resultKind;
  bool _resultFromAi = false;
  String? _error;

  bool get _hasText => widget.documentText.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    onDispose(_questionController.dispose);
  }

  Future<void> _ask() async {
    final question = _questionController.text.trim();
    if (question.isEmpty || _isBusy || !_hasText) return;

    final state = context.read<ChatAiState>();
    final generative = state.isGenerativeAvailable;
    setState(() {
      _isBusy = true;
      _result = null;
      _resultKind = null;
      _error = null;
    });
    try {
      final answer = await state.askAboutDocument(
        documentText: widget.documentText,
        question: question,
      );
      if (!mounted) return;
      setState(() {
        _result = answer;
        _resultKind = _ResultKind.ask;
        _resultFromAi = generative;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _summarize() {
    if (_isBusy || !_hasText) return;
    final l10n = AppLocalizations.of(context);
    final summary = TextAnalysisHelper.summarize(widget.documentText);
    setState(() {
      _error = null;
      _resultKind = _ResultKind.summary;
      _resultFromAi = false;
      _result = summary.isNotEmpty ? summary : l10n.pdfExtractTextEmpty;
    });
  }

  void _keywords() {
    if (_isBusy || !_hasText) return;
    final l10n = AppLocalizations.of(context);
    final keywords = TextAnalysisHelper.extractKeywords(widget.documentText);
    setState(() {
      _error = null;
      _resultKind = _ResultKind.keywords;
      _resultFromAi = false;
      _result = keywords.isNotEmpty
          ? keywords.join(', ')
          : l10n.pdfExtractTextEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final state = context.watch<ChatAiState>();
    final isTruncated =
        state.isGenerativeAvailable &&
        widget.documentText.length > ChatAiState.maxDocumentContextChars;

    String? resultLabel;
    switch (_resultKind) {
      case _ResultKind.ask:
        resultLabel = _resultFromAi
            ? l10n.textToolsSourceAi
            : l10n.textToolsSourceOffline;
        break;
      case _ResultKind.summary:
        resultLabel = l10n.textToolsSummaryTitle;
        break;
      case _ResultKind.keywords:
        resultLabel = l10n.textToolsKeywordsTitle;
        break;
      case null:
        resultLabel = null;
        break;
    }

    final Widget resultArea;
    if (_isBusy) {
      resultArea = Row(
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
      resultArea = Text(
        _error!,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.error,
        ),
      );
    } else if (_result == null) {
      resultArea = const SizedBox.shrink();
    } else {
      resultArea = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (resultLabel != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6.0),
              child: Text(
                resultLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          Container(
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
              child: SelectableText(
                _result!,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ),
        ],
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
                      enabled: _hasText,
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
                    onPressed: (_isBusy || !_hasText) ? null : _ask,
                    icon: const Icon(Icons.send, size: 18),
                    label: Text(l10n.pdfExtractTextAskSend),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  OutlinedButton.icon(
                    onPressed: (_isBusy || !_hasText) ? null : _summarize,
                    icon: const Icon(Icons.subject, size: 18),
                    label: Text(l10n.textToolsSummarize),
                  ),
                  OutlinedButton.icon(
                    onPressed: (_isBusy || !_hasText) ? null : _keywords,
                    icon: const Icon(Icons.label_outline, size: 18),
                    label: Text(l10n.textToolsKeywords),
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
              resultArea,
            ],
          ),
        ),
      ],
    );
  }
}
