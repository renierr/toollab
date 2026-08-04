import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/file_manager/file_manager_entry.dart';
import 'package:tool_lab/tools/file_manager/widgets/file_manager_entry_name_list.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

class FileManagerDeleteDialog extends StatelessWidget {
  final List<FileManagerEntry> entries;

  /// File counts for the folders in the visible part of the list, keyed by path.
  final Map<String, int> folderFileCounts;

  const FileManagerDeleteDialog({
    super.key,
    required this.entries,
    required this.folderFileCounts,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ResponsiveAlertDialog(
      title: Text(l10n.fileManagerDeleteTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.fileManagerDeleteMessage(entries.length)),
          const SizedBox(height: 12),
          FileManagerEntryNameList(labels: _labels(l10n)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.commonDelete),
        ),
      ],
    );
  }

  List<String> _labels(AppLocalizations l10n) => entries.map((entry) {
    final fileCount = folderFileCounts[entry.path];
    return fileCount == null
        ? entry.name
        : '${entry.name} · ${l10n.fileManagerFolderFileCount(fileCount)}';
  }).toList();
}
