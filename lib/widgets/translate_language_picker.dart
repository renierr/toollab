import 'package:flutter/material.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/services/translation/translation_service.dart';

/// Target language dropdown for on-device translation; null means automatic.
class TranslateLanguagePicker extends StatelessWidget {
  final TranslateLanguage? value;
  final ValueChanged<TranslateLanguage>? onChanged;

  const TranslateLanguagePicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final onChanged = this.onChanged;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.translate, size: 18),
        const SizedBox(width: 8),
        Flexible(
          child: DropdownButton<TranslateLanguage>(
            isExpanded: true,
            value: value,
            hint: Text(
              l10n.textAiTargetAuto,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            items: [
              for (final language in TranslationService.languages)
                DropdownMenuItem(
                  value: language,
                  child: Text(
                    TranslationService.displayName(language),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: onChanged == null
                ? null
                : (language) {
                    if (language != null) onChanged(language);
                  },
          ),
        ),
      ],
    );
  }
}
