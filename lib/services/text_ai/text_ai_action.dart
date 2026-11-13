import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

/// One-shot text actions offered by the shared text AI sheet.
enum TextAiAction {
  proofread(Icons.spellcheck),
  formal(Icons.business_center_outlined),
  shorter(Icons.short_text),
  friendly(Icons.sentiment_satisfied_outlined),
  summarize(Icons.subject),
  translate(Icons.translate);

  final IconData icon;

  const TextAiAction(this.icon);

  static const editing = [proofread, formal, shorter, friendly];
  static const reading = [summarize, translate];

  /// Needs Gemini Nano; summarize falls back to offline extraction and
  /// translate uses ML Kit Translation instead.
  bool get needsGenerative =>
      this != TextAiAction.summarize && this != TextAiAction.translate;

  /// Output replaces the input rather than describing it.
  bool get rewritesText => this != TextAiAction.summarize;

  String label(AppLocalizations l10n) => switch (this) {
    proofread => l10n.textAiProofread,
    formal => l10n.textAiFormal,
    shorter => l10n.textAiShorter,
    friendly => l10n.textAiFriendly,
    summarize => l10n.textToolsSummarize,
    translate => l10n.textAiTranslate,
  };

  String? get instruction => switch (this) {
    proofread =>
      'Correct spelling, grammar and punctuation in the following text. '
          'Keep its meaning, language, tone and Markdown formatting.',
    formal =>
      'Rewrite the following text in a formal, professional tone. '
          'Keep its language and Markdown formatting.',
    shorter =>
      'Rewrite the following text to be shorter and more concise without '
          'losing important information. Keep its language and Markdown '
          'formatting.',
    friendly =>
      'Rewrite the following text in a friendlier, warmer tone. Keep its '
          'language and Markdown formatting.',
    summarize =>
      'Summarize the following text in a few short bullet points, written '
          'in the same language as the text.',
    translate => null,
  };
}
