import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/helpers/clipboard_helper.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/helpers/text_analysis_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/services/text_ai/text_ai_action.dart';
import 'package:tool_lab/services/translation/translation_service.dart';
import 'package:tool_lab/tools/chat_ai/chat_ai_state.dart';
import 'package:tool_lab/widgets/genai_status_banner.dart';
import 'package:tool_lab/widgets/translate_language_picker.dart';

enum TextAiApply { replace, insert }

typedef TextAiResult = ({String text, TextAiApply apply});

/// Proofread, rewrite, summarize or translate a piece of text on device.
class TextAiSheet extends StatefulWidget {
  final String text;
  final List<TextAiAction> actions;
  final bool canApply;
  final TextAiAction? initialAction;

  const TextAiSheet({
    super.key,
    required this.text,
    required this.actions,
    required this.canApply,
    this.initialAction,
  });

  static Future<TextAiResult?> show(
    BuildContext context, {
    required String text,
    List<TextAiAction> actions = TextAiAction.values,
    bool canApply = true,
    TextAiAction? initialAction,
  }) {
    return showModalBottomSheet<TextAiResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => TextAiSheet(
        text: text,
        actions: actions,
        canApply: canApply,
        initialAction: initialAction,
      ),
    );
  }

  @override
  State<TextAiSheet> createState() => _TextAiSheetState();
}

class _TextAiSheetState extends State<TextAiSheet> {
  StreamSubscription<String>? _subscription;
  TextAiAction? _action;
  String _result = '';
  String? _note;
  String? _error;
  bool _busy = false;
  TranslateLanguage? _target;
  int _run = 0;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialAction;
    if (initial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _isEnabled(initial, context.read<ChatAiState>())) {
          _start(initial);
        }
      });
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  bool _isEnabled(TextAiAction action, ChatAiState ai) {
    if (action == TextAiAction.translate) return TranslationService.isSupported;
    return !action.needsGenerative || ai.isGenerativeAvailable;
  }

  Future<void> _start(TextAiAction action) async {
    final l10n = AppLocalizations.of(context);
    final ai = context.read<ChatAiState>();
    final languageCode = Localizations.localeOf(context).languageCode;
    final run = ++_run;
    await _subscription?.cancel();
    _subscription = null;
    setState(() {
      _action = action;
      _result = '';
      _note = null;
      _error = null;
      _busy = true;
    });

    final text = widget.text;
    const limit = ChatAiState.maxDocumentContextChars;
    try {
      if (action == TextAiAction.translate) {
        await _translate(run, text, languageCode, l10n);
      } else if (action == TextAiAction.summarize &&
          !ai.isGenerativeAvailable) {
        final summary = TextAnalysisHelper.summarize(text);
        _finish(run, summary, note: l10n.textToolsSummaryTitle);
      } else if (action.rewritesText && text.length > limit) {
        _fail(run, l10n.textAiTooLong(limit));
      } else {
        final input = text.length > limit ? text.substring(0, limit) : text;
        _subscription = ai
            .streamTextTask(instruction: action.instruction!, text: input)
            .listen(
              (chunk) {
                if (run == _run) setState(() => _result += chunk);
              },
              onError: (Object e) => _fail(run, e.toString()),
              onDone: () => _finish(
                run,
                _result.trim(),
                note: text.length > limit
                    ? l10n.pdfExtractTextTruncatedNote
                    : null,
              ),
            );
      }
    } catch (e) {
      errorLog('[TextAiSheet] ${action.name} failed: $e');
      _fail(run, e.toString());
    }
  }

  Future<void> _translate(
    int run,
    String text,
    String languageCode,
    AppLocalizations l10n,
  ) async {
    final service = TranslationService.instance;
    final source = TranslationService.languageFor(
      await service.identifyLanguage(text),
    );
    if (source == null) {
      _fail(run, l10n.textAiLanguageUnknown);
      return;
    }
    final target =
        _target ?? TranslationService.defaultTarget(languageCode, source);
    final ready =
        await service.isModelReady(source) &&
        await service.isModelReady(target);
    if (run != _run) return;
    setState(() {
      _target = target;
      if (!ready) _note = l10n.textAiDownloadingLanguage;
    });
    final translated = await service.translate(
      text,
      source: source,
      target: target,
    );
    _finish(
      run,
      translated,
      note: l10n.textAiTranslatedFrom(
        source.bcpCode.toUpperCase(),
        target.bcpCode.toUpperCase(),
      ),
    );
  }

  void _finish(int run, String result, {String? note}) {
    if (run != _run || !mounted) return;
    setState(() {
      _result = result;
      _note = note;
      _busy = false;
    });
  }

  void _fail(int run, String message) {
    if (run != _run || !mounted) return;
    setState(() {
      _error = message;
      _busy = false;
    });
  }

  void _setTarget(TranslateLanguage language) {
    setState(() => _target = language);
    if (_action == TextAiAction.translate) _start(TextAiAction.translate);
  }

  Future<void> _copy() async {
    final l10n = AppLocalizations.of(context);
    await ClipboardHelper.setText(_result);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.textAiCopied)));
  }

  void _apply(TextAiApply apply) {
    Navigator.of(context).pop<TextAiResult>((text: _result, apply: apply));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final ai = context.watch<ChatAiState>();
    final action = _action;
    final done = !_busy && _error == null && _result.isNotEmpty;
    final showsTranslate =
        widget.actions.contains(TextAiAction.translate) &&
        TranslationService.isSupported;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.textAiTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: GenAiStatusBanner(
                status: ai.featureStatus,
                downloadProgress: ai.downloadProgress,
                onDownload: ai.downloadModel,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final a in widget.actions)
                  ChoiceChip(
                    avatar: Icon(a.icon, size: 18),
                    label: Text(a.label(l10n)),
                    selected: a == action,
                    onSelected: _isEnabled(a, ai) ? (_) => _start(a) : null,
                  ),
              ],
            ),
            if (showsTranslate) ...[
              const SizedBox(height: 8),
              TranslateLanguagePicker(
                value: _target,
                onChanged: _busy ? null : _setTarget,
              ),
            ],
            const SizedBox(height: 12),
            if (action != null)
              _ResultView(
                text: _result,
                note: _note,
                error: _error,
                busy: _busy,
              ),
            if (done) ...[
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: _copy,
                    icon: const Icon(Icons.copy, size: 18),
                    label: Text(l10n.commonCopy),
                  ),
                  if (widget.canApply) ...[
                    OutlinedButton.icon(
                      onPressed: () => _apply(TextAiApply.insert),
                      icon: const Icon(Icons.playlist_add, size: 18),
                      label: Text(l10n.textAiInsert),
                    ),
                    if (action!.rewritesText)
                      FilledButton.icon(
                        onPressed: () => _apply(TextAiApply.replace),
                        icon: const Icon(Icons.check, size: 18),
                        label: Text(l10n.textAiReplace),
                      ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  final String text;
  final String? note;
  final String? error;
  final bool busy;

  const _ResultView({
    required this.text,
    required this.note,
    required this.error,
    required this.busy,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final error = this.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (busy)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    note ?? l10n.pdfExtractTextThinking,
                    style: muted,
                  ),
                ),
              ],
            ),
          )
        else if (note != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(note!, style: muted),
          ),
        if (error != null)
          Text(
            error,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          )
        else if (text.isNotEmpty)
          Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.4,
            ),
            decoration: BoxDecoration(
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.2),
              ),
              borderRadius: BorderRadius.circular(12),
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.15),
            ),
            padding: const EdgeInsets.all(12),
            child: SingleChildScrollView(
              child: SelectableText(text, style: theme.textTheme.bodyMedium),
            ),
          ),
      ],
    );
  }
}
