import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/file_manager/file_manager_installed_apps.dart';
import 'package:tool_lab/tools/file_manager/file_manager_state.dart';

class FileManagerCategoryPicker extends StatelessWidget {
  final FileManagerState state;
  final ValueChanged<FileManagerCategory> onSelected;
  final bool narrow;

  const FileManagerCategoryPicker({
    super.key,
    required this.state,
    required this.onSelected,
    required this.narrow,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = <(FileManagerCategory, IconData, String)>[
      (
        FileManagerCategory.images,
        Icons.photo_outlined,
        l10n.fileManagerCategoryImages,
      ),
      (
        FileManagerCategory.system,
        Icons.dns_outlined,
        l10n.fileManagerCategorySystem,
      ),
      if (FileManagerInstalledApps.isSupported)
        (
          FileManagerCategory.apps,
          Icons.apps_outlined,
          l10n.fileManagerCategoryApps,
        ),
    ];
    return PopupMenuButton<FileManagerCategory>(
      tooltip: l10n.fileManagerCategories,
      onSelected: onSelected,
      itemBuilder: (context) => items
          .map(
            (item) => PopupMenuItem(
              value: item.$1,
              child: Row(
                children: [
                  Icon(item.$2, size: 20),
                  const SizedBox(width: 12),
                  Text(item.$3),
                  if (state.category == item.$1) ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.check,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ],
              ),
            ),
          )
          .toList(),
      child: narrow
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
              child: Chip(
                avatar: const Icon(Icons.category_outlined, size: 18),
                label: Text(l10n.fileManagerCategories),
              ),
            )
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  const Icon(Icons.category_outlined),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      state.isBrowsingCategory
                          ? state.categoryTitle(l10n)
                          : l10n.fileManagerCategories,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.expand_more),
                ],
              ),
            ),
    );
  }
}
