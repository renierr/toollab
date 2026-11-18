import 'package:material_ui/material_ui.dart';
import 'package:tool_lab/helpers/format_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/pages/maintenance/storage_entry_tile.dart';
import 'package:tool_lab/services/storage_usage_service.dart';
import 'package:tool_lab/widgets/readable_width.dart';

class StorageBrowserPage extends StatefulWidget {
  final String title;
  final String path;

  const StorageBrowserPage({
    super.key,
    required this.title,
    required this.path,
  });

  static Future<void> open(BuildContext context, StorageEntry entry) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StorageBrowserPage(title: entry.name, path: entry.path),
      ),
    );
  }

  @override
  State<StorageBrowserPage> createState() => _StorageBrowserPageState();
}

class _StorageBrowserPageState extends State<StorageBrowserPage> {
  late Future<List<StorageEntry>> _entries = StorageUsageService.children(
    widget.path,
  );

  void _refresh() =>
      setState(() => _entries = StorageUsageService.children(widget.path));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: l10n.coreStorageRefresh,
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: FutureBuilder<List<StorageEntry>>(
        future: _entries,
        builder: (context, snapshot) {
          final entries = snapshot.data;
          if (entries == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (entries.isEmpty) {
            return Center(child: Text(l10n.coreStorageEmpty));
          }
          final total = entries.fold(0, (sum, e) => sum + e.bytes);
          return ReadableScrollPadding(
            padding: const EdgeInsets.all(16),
            builder: (context, padding) => ListView.builder(
              padding: padding,
              itemCount: entries.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.coreStorageTotal(FormatHelper.fileSize(total)),
                          style: theme.textTheme.titleMedium,
                        ),
                        SelectableText(
                          widget.path,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  );
                }
                final entry = entries[index - 1];
                return StorageEntryTile(
                  entry: entry,
                  totalBytes: total,
                  onTap: entry.isDirectory
                      ? () => StorageBrowserPage.open(context, entry)
                      : null,
                );
              },
            ),
          );
        },
      ),
    );
  }
}
