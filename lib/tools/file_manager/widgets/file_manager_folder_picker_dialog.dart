import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

/// Browses local folders and returns the picked path. Used for bulk moves,
/// where the destination is not the folder currently open.
class FileManagerFolderPickerDialog extends StatefulWidget {
  final String initialPath;

  const FileManagerFolderPickerDialog({super.key, required this.initialPath});

  @override
  State<FileManagerFolderPickerDialog> createState() =>
      _FileManagerFolderPickerDialogState();
}

class _FileManagerFolderPickerDialogState
    extends State<FileManagerFolderPickerDialog> {
  late String _path = widget.initialPath;
  List<Directory> _folders = const [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final folders = <Directory>[];
    try {
      await for (final entity in Directory(_path).list(followLinks: false)) {
        if (entity is Directory && !p.basename(entity.path).startsWith('.')) {
          folders.add(entity);
        }
      }
    } catch (_) {
      // An unreadable folder simply shows up empty.
    }
    folders.sort(
      (a, b) => p
          .basename(a.path)
          .toLowerCase()
          .compareTo(p.basename(b.path).toLowerCase()),
    );
    if (!mounted) return;
    setState(() {
      _folders = folders;
      _isLoading = false;
    });
  }

  void _open(String path) {
    setState(() => _path = path);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final parent = p.dirname(_path);
    final canGoUp = parent != _path;
    return ResponsiveAlertDialog(
      title: Text(l10n.fileManagerChooseDestination),
      content: SizedBox(
        width: 420,
        height: 380,
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: l10n.commonBack,
                  onPressed: canGoUp ? () => _open(parent) : null,
                  icon: const Icon(Icons.arrow_upward),
                ),
                Expanded(
                  child: Text(
                    _path,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Divider(height: 1),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _folders.isEmpty
                  ? Center(child: Text(l10n.fileManagerEmptyFolder))
                  : ListView.builder(
                      itemCount: _folders.length,
                      itemBuilder: (context, index) {
                        final folder = _folders[index];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.folder_outlined),
                          title: Text(
                            p.basename(folder.path),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => _open(folder.path),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_path),
          child: Text(l10n.fileManagerSelectFolder),
        ),
      ],
    );
  }
}
