import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
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
    ];

    return Card(
      margin: EdgeInsets.zero,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.transform_outlined,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: state.transformType,
                    dropdownColor: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    items: transforms
                        .map(
                          (t) => DropdownMenuItem(
                            value: t['id'],
                            child: Text(
                              t['name']!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        state.setTransformType(val);
                      }
                    },
                  ),
                ),
              ],
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed:
                  state.inputText.isNotEmpty || state.outputText.isNotEmpty
                  ? () => state.swap()
                  : null,
              icon: const Icon(Icons.swap_horiz, size: 18),
              label: Text(l10n.stringTransformerSwap),
            ),
          ],
        ),
      ),
    );
  }
}
