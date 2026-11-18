import 'package:flutter/material.dart';
import 'package:tool_lab/helpers/format_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/pages/maintenance/storage_browser_page.dart';
import 'package:tool_lab/pages/maintenance/storage_entry_tile.dart';
import 'package:tool_lab/services/storage_usage_service.dart';
import 'package:tool_lab/theme/theme.dart';

class StorageUsageCard extends StatefulWidget {
  const StorageUsageCard({super.key});

  @override
  State<StorageUsageCard> createState() => _StorageUsageCardState();
}

class _StorageUsageCardState extends State<StorageUsageCard> {
  late Future<List<StorageRoot>> _roots = StorageUsageService.roots();

  void _refresh() => setState(() => _roots = StorageUsageService.roots());

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.storage_outlined,
                  color: AppTheme.accentBlue,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.coreStorageTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l10n.coreStorageRefresh,
                  icon: const Icon(Icons.refresh),
                  onPressed: _refresh,
                ),
              ],
            ),
            Text(
              l10n.coreStorageDescription,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<StorageRoot>>(
              future: _roots,
              builder: (context, snapshot) {
                final roots = snapshot.data;
                if (roots == null) {
                  return Text(
                    l10n.coreStorageLoading,
                    style: theme.textTheme.bodySmall,
                  );
                }
                final total = roots.fold(0, (sum, r) => sum + r.bytes);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.coreStorageTotal(FormatHelper.fileSize(total)),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    for (final root in roots)
                      _StorageRootSection(root: root, totalBytes: total),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StorageRootSection extends StatelessWidget {
  final StorageRoot root;
  final int totalBytes;

  const _StorageRootSection({required this.root, required this.totalBytes});

  String _label(AppLocalizations l10n) => switch (root.kind) {
    StorageRootKind.appData => l10n.coreStorageRootAppData,
    StorageRootKind.externalAppData => l10n.coreStorageRootExternal,
    StorageRootKind.appSupport => l10n.coreStorageRootSupport,
    StorageRootKind.cache => l10n.coreStorageRootCache,
    StorageRootKind.temp => l10n.coreStorageRootTemp,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          '${_label(l10n)} · ${FormatHelper.fileSize(root.bytes)}',
          style: theme.textTheme.titleSmall,
        ),
        Text(
          root.path,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (root.children.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              l10n.coreStorageEmpty,
              style: theme.textTheme.bodySmall,
            ),
          ),
        for (final entry in root.children)
          StorageEntryTile(
            entry: entry,
            totalBytes: totalBytes,
            onTap: entry.isDirectory
                ? () => StorageBrowserPage.open(context, entry)
                : null,
          ),
      ],
    );
  }
}
