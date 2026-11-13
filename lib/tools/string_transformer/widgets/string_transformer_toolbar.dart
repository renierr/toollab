import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/services/translation/translation_service.dart';
import 'package:tool_lab/widgets/translate_language_picker.dart';
import '../string_transformer_state.dart';

class StringTransformerToolbar extends StatelessWidget {
  const StringTransformerToolbar({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = context.watch<StringTransformerState>();

    final transforms = [
      {'id': 'camel-case', 'name': l10n.stringTransformerTypeCamel},
      {'id': 'snake-case', 'name': l10n.stringTransformerTypeSnake},
      {'id': 'kebab-case', 'name': l10n.stringTransformerTypeKebab},
      {'id': 'pascal-case', 'name': l10n.stringTransformerTypePascal},
      {'id': 'url-slug', 'name': l10n.stringTransformerTypeUrlSlug},
      {'id': 'base64-encode', 'name': l10n.stringTransformerTypeBase64Encode},
      {'id': 'base64-decode', 'name': l10n.stringTransformerTypeBase64Decode},
      {'id': 'hex-encode', 'name': l10n.stringTransformerTypeHexEncode},
      {'id': 'hex-decode', 'name': l10n.stringTransformerTypeHexDecode},
      {'id': 'ad-url-decode', 'name': l10n.stringTransformerTypeAdUrlDecode},
      if (TranslationService.isSupported)
        {
          'id': StringTransformerState.translateType,
          'name': l10n.stringTransformerTypeTranslate,
        },
    ];
    final translating =
        state.transformType == StringTransformerState.translateType;
    final detected = state.detectedLanguage;

    final status = state.translating
        ? l10n.stringTransformerTranslating
        : detected == null
        ? null
        : l10n.stringTransformerDetected(
            TranslationService.displayName(detected),
          );

    return Card(
      margin: EdgeInsets.zero,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.transform_outlined,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: state.transformType,
                      dropdownColor: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      items: transforms
                          .map(
                            (t) => DropdownMenuItem(
                              value: t['id'],
                              child: Text(
                                t['name']!,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) state.setTransformType(val);
                      },
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l10n.stringTransformerSwap,
                  onPressed:
                      state.inputText.isNotEmpty || state.outputText.isNotEmpty
                      ? state.swap
                      : null,
                  icon: const Icon(Icons.swap_vert),
                ),
              ],
            ),
            if (translating)
              Padding(
                padding: const EdgeInsets.only(right: 12, bottom: 4),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 240),
                      child: TranslateLanguagePicker(
                        value: state.targetLanguage,
                        onChanged: state.setTargetLanguage,
                      ),
                    ),
                    if (status != null)
                      Text(
                        status,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
