import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tool_lab/helpers/format_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/file_manager/file_manager_entry.dart';
import 'package:tool_lab/tools/file_manager/widgets/file_manager_entry_icon.dart';
import 'package:tool_lab/tools/file_manager/widgets/file_manager_file_name.dart';
import 'package:tool_lab/widgets/responsive_layout.dart';

class FileManagerEntryTile extends StatelessWidget {
  final FileManagerEntry entry;
  final ValueChanged<FileManagerEntry> onOpen;
  final ValueChanged<FileManagerEntry> onOpenWithSystem;
  final ValueChanged<FileManagerEntry> onShare;
  final ValueChanged<FileManagerEntry> onDetails;
  final ValueChanged<FileManagerEntry> onRename;
  final ValueChanged<FileManagerEntry> onDelete;
  final ValueChanged<FileManagerEntry> onCopy;
  final ValueChanged<FileManagerEntry> onCut;
  final ValueChanged<FileManagerEntry> onExtract;
  final bool showClipboardActions;
  final bool selectionMode;
  final bool selected;
  final ValueChanged<FileManagerEntry> onToggleSelection;
  final bool isInClipboard;
  final bool clipboardIsCut;
  final bool readOnly;
  final bool showImagePreviews;
  final ValueListenable<FileStat?> metadata;
  final ValueListenable<int?> childCount;

  const FileManagerEntryTile({
    super.key,
    required this.entry,
    required this.onOpen,
    required this.onOpenWithSystem,
    required this.onShare,
    required this.onDetails,
    required this.onRename,
    required this.onDelete,
    required this.onCopy,
    required this.onCut,
    required this.onExtract,
    required this.showClipboardActions,
    required this.selectionMode,
    required this.selected,
    required this.onToggleSelection,
    required this.isInClipboard,
    required this.clipboardIsCut,
    required this.readOnly,
    required this.showImagePreviews,
    required this.metadata,
    required this.childCount,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact =
            constraints.maxWidth < ResponsiveLayout.mobileBreakpoint;
        final iconSize = isCompact ? 40.0 : 48.0;
        return ListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: isCompact ? 12 : 16),
          minLeadingWidth: iconSize,
          leading: SizedBox(
            width: iconSize,
            height: iconSize,
            child: Center(
              child: FileManagerEntryIcon(
                entry: entry,
                showPreview: showImagePreviews,
              ),
            ),
          ),
          selected: selected,
          title: isCompact
              ? FileManagerFileName(name: entry.name)
              : Text(entry.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Row(
            children: [
              Expanded(
                child: _EntryMetadata(
                  entry: entry,
                  metadata: metadata,
                  childCount: childCount,
                ),
              ),
              if (isInClipboard)
                Icon(
                  clipboardIsCut ? Icons.content_cut : Icons.copy_outlined,
                  size: 14,
                  color: Theme.of(context).colorScheme.primary,
                ),
            ],
          ),
          trailing: selectionMode
              ? Checkbox(
                  value: selected,
                  onChanged: (_) => onToggleSelection(entry),
                )
              : PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'rename') {
                      onRename(entry);
                    } else if (value == 'details') {
                      onDetails(entry);
                    } else if (value == 'system') {
                      onOpenWithSystem(entry);
                    } else if (value == 'install') {
                      onOpenWithSystem(entry);
                    } else if (value == 'share') {
                      onShare(entry);
                    } else if (value == 'extract') {
                      onExtract(entry);
                    } else if (value == 'copy') {
                      onCopy(entry);
                    } else if (value == 'cut') {
                      onCut(entry);
                    } else {
                      onDelete(entry);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'details',
                      child: _MenuAction(
                        icon: Icons.info_outline,
                        label: AppLocalizations.of(context).fileManagerDetails,
                      ),
                    ),
                    if (!readOnly && _isApk(entry))
                      PopupMenuItem(
                        value: 'install',
                        child: _MenuAction(
                          icon: Icons.install_mobile_outlined,
                          label: AppLocalizations.of(
                            context,
                          ).fileManagerInstallApk,
                        ),
                      ),
                    if (!readOnly && entry.name.toLowerCase().endsWith('.zip'))
                      PopupMenuItem(
                        value: 'extract',
                        child: _MenuAction(
                          icon: Icons.unarchive_outlined,
                          label: AppLocalizations.of(
                            context,
                          ).fileManagerExtract,
                        ),
                      ),
                    PopupMenuItem(
                      value: 'system',
                      child: _MenuAction(
                        icon: Icons.open_in_new,
                        label: AppLocalizations.of(
                          context,
                        ).fileManagerOpenWithSystem,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'share',
                      child: _MenuAction(
                        icon: Icons.share_outlined,
                        label: AppLocalizations.of(context).commonShare,
                      ),
                    ),
                    if (!readOnly)
                      PopupMenuItem(
                        value: 'rename',
                        child: _MenuAction(
                          icon: Icons.drive_file_rename_outline,
                          label: AppLocalizations.of(context).commonRename,
                        ),
                      ),
                    if (showClipboardActions)
                      PopupMenuItem(
                        value: 'copy',
                        child: _MenuAction(
                          icon: Icons.copy_outlined,
                          label: AppLocalizations.of(context).commonCopy,
                        ),
                      ),
                    if (showClipboardActions && !readOnly)
                      PopupMenuItem(
                        value: 'cut',
                        child: _MenuAction(
                          icon: Icons.content_cut,
                          label: AppLocalizations.of(context).fileManagerCut,
                        ),
                      ),
                    if (!readOnly)
                      PopupMenuItem(
                        value: 'delete',
                        child: _MenuAction(
                          icon: Icons.delete_outline,
                          label: AppLocalizations.of(context).commonDelete,
                        ),
                      ),
                  ],
                ),
          onTap: () => selectionMode ? onToggleSelection(entry) : onOpen(entry),
          onLongPress: () => onToggleSelection(entry),
        );
      },
    );
  }

  bool _isApk(FileManagerEntry entry) =>
      !entry.isDirectory && entry.name.toLowerCase().endsWith('.apk');
}

class _EntryMetadata extends StatelessWidget {
  final FileManagerEntry entry;
  final ValueListenable<FileStat?> metadata;
  final ValueListenable<int?> childCount;

  const _EntryMetadata({
    required this.entry,
    required this.metadata,
    required this.childCount,
  });

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<FileStat?>(
    valueListenable: metadata,
    builder: (context, stat, _) => ValueListenableBuilder<int?>(
      valueListenable: childCount,
      builder: (context, count, _) {
        final modified = entry.modified ?? stat?.modified;
        final size = entry.size ?? (entry.isDirectory ? null : stat?.size);
        final parts = <String>[];
        if (modified != null) parts.add(FormatHelper.dateTime(modified));
        if (size != null) parts.add(FormatHelper.fileSize(size));
        if (count != null) {
          parts.add(AppLocalizations.of(context).fileManagerItemCount(count));
        }
        return Text(
          parts.join('  -  '),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 11,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      },
    ),
  );
}

class _MenuAction extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MenuAction({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    children: [Icon(icon, size: 20), const SizedBox(width: 12), Text(label)],
  );
}
