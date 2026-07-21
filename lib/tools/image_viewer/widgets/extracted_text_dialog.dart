import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';
import 'package:tool_lab/widgets/selectable_text_view.dart';
import 'package:tool_lab/helpers/clipboard_helper.dart';

class ExtractedTextDialog extends StatelessWidget {
  final String text;
  final String fileName;

  const ExtractedTextDialog({
    super.key,
    required this.text,
    required this.fileName,
  });

  static void show({
    required BuildContext context,
    required String text,
    required String fileName,
  }) {
    showDialog(
      context: context,
      builder: (context) => ExtractedTextDialog(text: text, fileName: fileName),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final trimmedText = text.trim();
    final hasText = trimmedText.isNotEmpty;

    return ResponsiveAlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.text_fields_outlined,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.imgViewExtractTextTitle,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            fileName,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: SelectableTextView(
          text: trimmedText,
          emptyMessage: l10n.imgViewExtractTextNoText,
          maxHeight: MediaQuery.of(context).size.height * 0.45,
        ),
      ),
      actions: [
        if (hasText)
          TextButton.icon(
            onPressed: () async {
              await ClipboardHelper.setText(trimmedText);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.imgViewTextCopied),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            icon: const Icon(Icons.copy_all, size: 18),
            label: Text(l10n.imgViewCopyToClipboard),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonClose),
        ),
      ],
    );
  }
}
