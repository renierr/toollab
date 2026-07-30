import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tool_lab/helpers/syntax/language_detector.dart';
import 'package:tool_lab/helpers/syntax/language_registry.dart';
import 'package:tool_lab/helpers/syntax/syntax_highlighter.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

/// A fenced markdown code block with TextMate syntax highlighting.
///
/// The language comes from the fence info string; a bare fence falls back to
/// [LanguageDetector]. Grammars must already be cached by
/// [SyntaxHighlighter.preload] — otherwise the code renders unhighlighted.
class MarkdownCodeBlock extends StatefulWidget {
  final String code;
  final String? fenceLanguage;
  final double scale;

  const MarkdownCodeBlock({
    super.key,
    required this.code,
    this.fenceLanguage,
    this.scale = 1.0,
  });

  @override
  State<MarkdownCodeBlock> createState() => _MarkdownCodeBlockState();
}

class _MarkdownCodeBlockState extends State<MarkdownCodeBlock> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final code = widget.code;
    final fenceLanguage = widget.fenceLanguage;

    final String? named = LanguageRegistry.resolveAlias(fenceLanguage);
    final bool autoDetected = named == null;
    final String? language = named ?? LanguageDetector.detect(code);

    final codeStyle = TextStyle(
      fontFamily: 'monospace',
      fontFamilyFallback: const ['Courier', 'Consolas'],
      fontSize: 14,
      height: 1.4,
      color: theme.colorScheme.onSurface,
    );

    List<TextSpan> spans = [TextSpan(text: code)];
    bool highlighted = false;
    if (language != null) {
      final result = SyntaxHighlighter.tokenizeSync(code, language);
      if (result != null && result.tokens.isNotEmpty) {
        spans = SyntaxHighlighter.buildSpans(
          code,
          result.tokens,
          result.scopes,
          theme,
        );
        highlighted = true;
      }
    }

    final String? label = highlighted
        ? (autoDetected
              ? l10n.widgetMarkdownCodeLanguageAuto(language!)
              : language)
        : (fenceLanguage?.trim().isNotEmpty == true
              ? fenceLanguage!.trim()
              : null);

    // The markdown builder already wraps `pre` in a container carrying
    // styleSheet.codeblockDecoration, so no decoration is applied here.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _CodeBlockHeader(code: code, label: label),
        Scrollbar(
          controller: _scrollController,
          child: SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
            child: Text.rich(
              TextSpan(children: spans),
              style: codeStyle,
              softWrap: false,
              textScaler: TextScaler.linear(widget.scale),
            ),
          ),
        ),
      ],
    );
  }
}

class _CodeBlockHeader extends StatelessWidget {
  final String code;
  final String? label;

  const _CodeBlockHeader({required this.code, this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.only(left: 16.0, right: 4.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label ?? '',
              style: theme.textTheme.labelSmall?.copyWith(
                fontFamily: 'monospace',
                color: theme.colorScheme.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy_outlined, size: 16),
            visualDensity: VisualDensity.compact,
            tooltip: l10n.widgetMarkdownCodeCopy,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: code));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.widgetMarkdownCodeCopied),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
