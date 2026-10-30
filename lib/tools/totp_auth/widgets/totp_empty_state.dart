import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

class TotpEmptyState extends StatelessWidget {
  final VoidCallback onScan;
  final VoidCallback onManual;
  final VoidCallback onImport;

  const TotpEmptyState({
    super.key,
    required this.onScan,
    required this.onManual,
    required this.onImport,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(
                    alpha: 0.55,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.shield_outlined,
                  size: 44,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                l10n.totpEmptyTitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.totpEmptyDescription,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: onScan,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: Text(l10n.totpScanQr),
                  ),
                  OutlinedButton.icon(
                    onPressed: onManual,
                    icon: const Icon(Icons.keyboard_outlined),
                    label: Text(l10n.totpEnterManually),
                  ),
                  TextButton.icon(
                    onPressed: onImport,
                    icon: const Icon(Icons.file_upload_outlined),
                    label: Text(l10n.totpImportAccounts),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
