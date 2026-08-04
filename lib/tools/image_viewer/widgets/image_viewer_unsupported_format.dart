import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

/// Fallback state for files no decoder handles — offers the system app instead.
class ImageViewerUnsupportedFormat extends StatelessWidget {
  final String fileName;
  final VoidCallback? onOpenExternally;
  final VoidCallback? onShare;
  final VoidCallback onChooseAnother;

  const ImageViewerUnsupportedFormat({
    super.key,
    required this.fileName,
    required this.onChooseAnother,
    this.onOpenExternally,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_not_supported_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.imgViewUnsupportedTitle,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Text(
                l10n.imgViewUnsupportedMessage(fileName),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                if (onOpenExternally != null)
                  FilledButton.icon(
                    onPressed: onOpenExternally,
                    icon: const Icon(Icons.open_in_new),
                    label: Text(l10n.imgViewOpenExternally),
                  ),
                if (onShare != null)
                  OutlinedButton.icon(
                    onPressed: onShare,
                    icon: const Icon(Icons.share_outlined),
                    label: Text(l10n.commonShare),
                  ),
                TextButton.icon(
                  onPressed: onChooseAnother,
                  icon: const Icon(Icons.folder_open),
                  label: Text(l10n.imgViewChooseAnother),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
