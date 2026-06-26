import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

class PdfRedactDonePage extends StatelessWidget {
  final String fileName;
  final int resultSize;
  final VoidCallback onDownload;
  final VoidCallback onShare;
  final VoidCallback onOpen;
  final VoidCallback onClose;

  const PdfRedactDonePage({
    super.key,
    required this.fileName,
    required this.resultSize,
    required this.onDownload,
    required this.onShare,
    required this.onOpen,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final sizeText = resultSize > 1024 * 1024
        ? '${(resultSize / (1024 * 1024)).toStringAsFixed(1)} MB'
        : resultSize > 1024
        ? '${(resultSize / 1024).toStringAsFixed(1)} KB'
        : '$resultSize B';

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.pdfEditRedactTitle(fileName)),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: onClose),
      ),
      body: Center(
        child: Padding(
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
              Text(
                l10n.pdfEditRedactDoneTitle,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.pdfEditRedactDoneSize(sizeText),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton.icon(
                    onPressed: onDownload,
                    icon: const Icon(Icons.download),
                    label: Text(l10n.pdfEditDownload),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: onShare,
                    icon: const Icon(Icons.share),
                    label: Text(l10n.commonShare),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: onOpen,
                icon: const Icon(Icons.open_in_new),
                label: Text(l10n.pdfEditOpenInViewer),
              ),
              const SizedBox(height: 8),
              TextButton(onPressed: onClose, child: Text(l10n.commonClose)),
            ],
          ),
        ),
      ),
    );
  }
}
