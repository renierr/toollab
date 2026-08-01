import 'package:flutter/material.dart';
import 'package:tool_lab/helpers/format_helper.dart';
import 'package:tool_lab/helpers/mime_type_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/file_manager/file_manager_entry.dart';
import 'package:tool_lab/widgets/data_row.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

class FileManagerDetailsDialog extends StatelessWidget {
  final FileManagerEntry entry;
  final VoidCallback onOpen;
  final VoidCallback onShare;

  const FileManagerDetailsDialog({
    super.key,
    required this.entry,
    required this.onOpen,
    required this.onShare,
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
            Icon(
              _iconFor(entry),
              size: 42,
              color: Theme.of(context).colorScheme.primary,
            ),
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

  IconData _iconFor(FileManagerEntry entry) {
    if (entry.isDirectory) return Icons.folder_outlined;
    final extension = entry.name.split('.').last.toLowerCase();
    return switch (extension) {
      'pdf' => Icons.picture_as_pdf_outlined,
      'md' || 'markdown' || 'txt' => Icons.article_outlined,
      'jpg' ||
      'jpeg' ||
      'png' ||
      'gif' ||
      'webp' ||
      'bmp' ||
      'svg' => Icons.image_outlined,
      'mp3' || 'wav' || 'ogg' || 'flac' || 'm4a' => Icons.audio_file_outlined,
      'mp4' || 'webm' || 'mov' || 'avi' => Icons.video_file_outlined,
      'zip' || '7z' || 'rar' || 'tar' || 'gz' => Icons.folder_zip_outlined,
      _ => Icons.insert_drive_file_outlined,
    };
  }
}
