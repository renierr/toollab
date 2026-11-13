import 'package:flutter/material.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/services/translation/translation_service.dart';

import '../translator_state.dart';

class TranslatorLanguageBar extends StatelessWidget {
  const TranslatorLanguageBar({super.key});

  static const _auto = 'auto';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<TranslatorState>();
    final detected = state.detected;
    final autoLabel = detected == null
        ? l10n.translatorDetectLanguage
        : l10n.translatorDetected(TranslationService.shortName(detected));

    return Card(
      margin: EdgeInsets.zero,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: _LanguageDropdown(
                value: state.source?.bcpCode ?? _auto,
                autoLabel: autoLabel,
                tooltip: l10n.translatorSourceLanguage,
                onChanged: (code) => state.setSource(
                  code == _auto ? null : TranslationService.languageFor(code),
                ),
              ),
            ),
            IconButton(
              tooltip: l10n.translatorSwap,
              onPressed: state.canSwap ? state.swap : null,
              icon: const Icon(Icons.swap_horiz),
            ),
            Expanded(
              child: _LanguageDropdown(
                value: state.target.bcpCode,
                tooltip: l10n.translatorTargetLanguage,
                onChanged: (code) {
                  final language = TranslationService.languageFor(code);
                  if (language != null) state.setTarget(language);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageDropdown extends StatelessWidget {
  final String value;
  final String? autoLabel;
  final String tooltip;
  final ValueChanged<String> onChanged;

  const _LanguageDropdown({
    required this.value,
    required this.tooltip,
    required this.onChanged,
    this.autoLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final autoLabel = this.autoLabel;
    final items = <(String, String)>[
      if (autoLabel != null) (TranslatorLanguageBar._auto, autoLabel),
      for (final TranslateLanguage language in TranslationService.languages)
        (language.bcpCode, TranslationService.displayName(language)),
    ];
    return Tooltip(
      message: tooltip,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: value,
          borderRadius: BorderRadius.circular(12),
          items: [
            for (final (code, label) in items)
              DropdownMenuItem(
                value: code,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
          onChanged: (code) {
            if (code != null) onChanged(code);
          },
        ),
      ),
    );
  }
}
