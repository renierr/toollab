import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

/// Success screen shared by the PDF operation panels: flatten, sign, organize
/// and metadata all end the same way.
class PdfResultView extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onDownload;
  final VoidCallback onShare;
  final VoidCallback onOpenInViewer;
  final VoidCallback onClose;

  const PdfResultView({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onDownload,
    required this.onShare,
    required this.onOpenInViewer,
    required this.onClose,
  });

  static String formatSize(int bytes) {
    if (bytes > 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes > 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '$bytes B';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle,
              size: 64,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: onDownload,
                  icon: const Icon(Icons.download),
                  label: Text(l10n.pdfEditDownload),
                ),
                OutlinedButton.icon(
                  onPressed: onShare,
                  icon: const Icon(Icons.share),
                  label: Text(l10n.commonShare),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: onOpenInViewer,
              icon: const Icon(Icons.open_in_new),
              label: Text(l10n.pdfEditOpenInViewer),
            ),
            TextButton(onPressed: onClose, child: Text(l10n.commonClose)),
          ],
        ),
      ),
    );
  }
}
