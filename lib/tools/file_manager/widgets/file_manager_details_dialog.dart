import 'package:flutter/material.dart';
import 'package:tool_lab/helpers/format_helper.dart';
import 'package:tool_lab/helpers/mime_type_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/file_manager/file_manager_entry.dart';
import 'package:tool_lab/tools/file_manager/widgets/file_manager_entry_icon.dart';
import 'package:tool_lab/widgets/data_row.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

class FileManagerDetailsDialog extends StatelessWidget {
  final FileManagerEntry entry;
  final VoidCallback onOpen;
  final VoidCallback onShare;
  final int? folderItemCount;

  const FileManagerDetailsDialog({
    super.key,
    required this.entry,
    required this.onOpen,
    required this.onShare,
    this.folderItemCount,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final mimeType = entry.isDirectory
        ? 'inode/directory'
        : MimeTypeHelper.getMimeType(entry.name);
    return ResponsiveAlertDialog(
      title: Text(l10n.fileManagerDetails),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FileManagerEntryIcon(entry: entry, size: 42),
            const SizedBox(height: 12),
            SelectableText(
              entry.name,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            InfoRow(
              label: l10n.fileManagerDetailSize,
              value: entry.isDirectory
                  ? l10n.fileManagerFolder
                  : entry.size == null
                  ? ''
                  : FormatHelper.fileSize(entry.size!),
            ),
            if (entry.isDirectory && folderItemCount != null)
              InfoRow(
                label: l10n.fileManagerFolderItems,
                value: l10n.fileManagerFolderItemCount(folderItemCount!),
              ),
            InfoRow(
              label: l10n.fileManagerDetailModified,
              value: entry.modified == null
                  ? ''
                  : FormatHelper.dateTime(entry.modified!),
            ),
            InfoRow(label: l10n.fileManagerDetailType, value: mimeType),
            InfoRow(label: l10n.fileManagerDetailPath, value: entry.path),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonClose),
        ),
        if (!entry.isDirectory)
          OutlinedButton.icon(
            onPressed: onShare,
            icon: const Icon(Icons.share_outlined),
            label: Text(l10n.commonShare),
          ),
        if (!entry.isDirectory)
          FilledButton.icon(
            onPressed: onOpen,
            icon: const Icon(Icons.open_in_new),
            label: Text(l10n.commonOpen),
          ),
      ],
    );
  }
}
