import 'package:flutter/material.dart';
import 'package:tool_lab/helpers/format_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/services/storage_usage_service.dart';

/// Explains the well-known folders of the Android app data dir.
String? storageFolderHint(AppLocalizations l10n, String name) => switch (name) {
  'app_flutter' => l10n.coreStorageHintDocuments,
  'files' => l10n.coreStorageHintAppFiles,
  'cache' => l10n.coreStorageHintCache,
  'code_cache' => l10n.coreStorageHintCodeCache,
  'databases' => l10n.coreStorageHintDatabases,
  'shared_prefs' => l10n.coreStorageHintPrefs,
  'app_webview' => l10n.coreStorageHintWebView,
  _ => null,
};

class StorageEntryTile extends StatelessWidget {
  final StorageEntry entry;
  final int totalBytes;
  final VoidCallback? onTap;

  const StorageEntryTile({
    super.key,
    required this.entry,
    required this.totalBytes,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final hint = storageFolderHint(l10n, entry.name);
    final fraction = totalBytes > 0 ? entry.bytes / totalBytes : 0.0;
    final details = [
      ?hint,
      if (entry.isDirectory) l10n.coreStorageFiles(entry.fileCount),
    ].join(' · ');

    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(
        entry.isDirectory
            ? Icons.folder_outlined
            : Icons.insert_drive_file_outlined,
        color: theme.colorScheme.primary,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              entry.name,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            FormatHelper.fileSize(entry.bytes),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: fraction.clamp(0.0, 1.0),
            minHeight: 4,
            borderRadius: BorderRadius.circular(2),
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(details, style: theme.textTheme.bodySmall),
          ],
        ],
      ),
      trailing: onTap != null ? const Icon(Icons.chevron_right) : null,
      onTap: onTap,
    );
  }
}
