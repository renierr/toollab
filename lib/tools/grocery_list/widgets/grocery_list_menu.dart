import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';

class GroceryListMenu extends StatelessWidget {
  final int checkedCount;
  final VoidCallback onReAddBought;
  final VoidCallback onClearBought;
  final VoidCallback onImport;
  final VoidCallback? onScanReceipt;
  final VoidCallback? onReceiptFile;
  final VoidCallback onExport;
  final VoidCallback onSync;
  final bool isSyncing;
  final bool hasBackend;

  const GroceryListMenu({
    super.key,
    required this.checkedCount,
    required this.onReAddBought,
    required this.onClearBought,
    required this.onImport,
    this.onScanReceipt,
    this.onReceiptFile,
    required this.onExport,
    required this.onSync,
    required this.isSyncing,
    required this.hasBackend,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (value) {
        switch (value) {
          case 're_add':
            onReAddBought();
          case 'clear':
            onClearBought();
          case 'import':
            onImport();
          case 'receipt':
            onScanReceipt?.call();
          case 'receipt_file':
            onReceiptFile?.call();
          case 'export':
            onExport();
          case 'sync':
            onSync();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 're_add',
          enabled: checkedCount > 0,
          child: Row(
            children: [
              const Icon(Icons.settings_backup_restore, size: 18),
              const SizedBox(width: 8),
              Text(l10n.groceryReAddBought),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'clear',
          enabled: checkedCount > 0,
          child: Row(
            children: [
              Icon(
                Icons.delete_sweep_outlined,
                size: 18,
                color: AppTheme.statusRed,
              ),
              const SizedBox(width: 8),
              Text(l10n.groceryClearBought),
            ],
          ),
        ),
        if (onScanReceipt != null || onReceiptFile != null)
          const PopupMenuDivider(),
        if (onScanReceipt != null)
          PopupMenuItem(
            value: 'receipt',
            child: Row(
              children: [
                const Icon(Icons.document_scanner_outlined, size: 18),
                const SizedBox(width: 8),
                Text(l10n.groceryScanReceipt),
              ],
            ),
          ),
        if (onReceiptFile != null)
          PopupMenuItem(
            value: 'receipt_file',
            child: Row(
              children: [
                const Icon(Icons.receipt_long_outlined, size: 18),
                const SizedBox(width: 8),
                Text(l10n.groceryReceiptFromFile),
              ],
            ),
          ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'import',
          child: Row(
            children: [
              const Icon(Icons.file_open_outlined, size: 18),
              const SizedBox(width: 8),
              Text(l10n.groceryImport),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'export',
          child: Row(
            children: [
              const Icon(Icons.file_download_outlined, size: 18),
              const SizedBox(width: 8),
              Text(l10n.groceryExport),
            ],
          ),
        ),
        if (hasBackend) ...[
          const PopupMenuDivider(),
          PopupMenuItem(
            value: 'sync',
            enabled: !isSyncing,
            child: Row(
              children: [
                isSyncing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync, size: 18),
                const SizedBox(width: 8),
                Text(l10n.grocerySync),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
