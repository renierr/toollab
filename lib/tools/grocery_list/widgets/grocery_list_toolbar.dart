import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';

class GroceryListToolbar extends StatelessWidget {
  final int uncheckedCount;
  final int checkedCount;
  final VoidCallback onReAddBought;
  final VoidCallback onClearBought;
  final VoidCallback onImport;
  final VoidCallback onExport;
  final VoidCallback onSync;
  final bool isSyncing;
  final bool hasBackend;

  const GroceryListToolbar({
    super.key,
    required this.uncheckedCount,
    required this.checkedCount,
    required this.onReAddBought,
    required this.onClearBought,
    required this.onImport,
    required this.onExport,
    required this.onSync,
    required this.isSyncing,
    required this.hasBackend,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 600;

          final stats = Text(
            l10n.groceryItemsCount(uncheckedCount, checkedCount),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          );

          final actions = Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: checkedCount > 0 ? onReAddBought : null,
                icon: const Icon(Icons.settings_backup_restore, size: 16),
                label: Text(l10n.groceryReAddBought),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: checkedCount > 0 ? onClearBought : null,
                icon: const Icon(Icons.delete_sweep_outlined, size: 16),
                label: Text(l10n.groceryClearBought),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  foregroundColor: AppTheme.statusRed,
                ),
              ),
              OutlinedButton.icon(
                onPressed: onImport,
                icon: const Icon(Icons.file_open_outlined, size: 16),
                label: Text(l10n.groceryImport),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: onExport,
                icon: const Icon(Icons.file_download_outlined, size: 16),
                label: Text(l10n.groceryExport),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                ),
              ),
              if (hasBackend)
                OutlinedButton.icon(
                  onPressed: isSyncing ? null : onSync,
                  icon: isSyncing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.grey,
                            ),
                          ),
                        )
                      : const Icon(Icons.sync, size: 16),
                  label: Text(l10n.grocerySync),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                ),
            ],
          );

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [stats, const SizedBox(height: 12), actions],
            );
          } else {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                stats,
                const SizedBox(width: 12),
                Flexible(child: actions),
              ],
            );
          }
        },
      ),
    );
  }
}
