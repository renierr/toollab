import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

class PdfRedactProcessingPage extends StatelessWidget {
  final String fileName;
  final VoidCallback onClose;

  const PdfRedactProcessingPage({
    super.key,
    required this.fileName,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.pdfEditRedactTitle(fileName)),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: onClose),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              l10n.pdfEditRedactProcessing,
              style: theme.textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}
