import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

class TotpAddSheet extends StatelessWidget {
  final VoidCallback onScan;
  final VoidCallback onManual;
  final VoidCallback onImport;

  const TotpAddSheet({
    super.key,
    required this.onScan,
    required this.onManual,
    required this.onImport,
  });

  static Future<void> show(
    BuildContext context, {
    required VoidCallback onScan,
    required VoidCallback onManual,
    required VoidCallback onImport,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => TotpAddSheet(
        onScan: () {
          Navigator.of(sheetContext).pop();
          onScan();
        },
        onManual: () {
          Navigator.of(sheetContext).pop();
          onManual();
        },
        onImport: () {
          Navigator.of(sheetContext).pop();
          onImport();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                l10n.totpAddAccount,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.qr_code_scanner),
              title: Text(l10n.totpScanQr),
              subtitle: Text(l10n.totpScanQrHint),
              onTap: onScan,
            ),
            ListTile(
              leading: const Icon(Icons.keyboard_outlined),
              title: Text(l10n.totpEnterManually),
              subtitle: Text(l10n.totpEnterManuallyHint),
              onTap: onManual,
            ),
            ListTile(
              leading: const Icon(Icons.file_upload_outlined),
              title: Text(l10n.totpImportAccounts),
              subtitle: Text(l10n.totpImportShortHint),
              onTap: onImport,
            ),
          ],
        ),
      ),
    );
  }
}
