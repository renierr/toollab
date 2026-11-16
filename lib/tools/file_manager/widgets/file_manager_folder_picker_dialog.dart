import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/file_manager/file_manager_list_focus.dart';
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
    extends State<FileManagerFolderPickerDialog>
    with DisposeCleanup {
  final ScrollController _scrollController = ScrollController();
  final FocusNode _listFocus = FocusNode(
    debugLabel: 'FileManagerFolderPickerList',
    canRequestFocus: false,
    skipTraversal: true,
  );
  late String _path = widget.initialPath;
  List<Directory> _folders = const [];
  bool _isLoading = true;
  bool _hadFocus = false;
  String? _cameFrom;

  @override
  void initState() {
    super.initState();
    onDispose(() {
      _scrollController.dispose();
      _listFocus.dispose();
    });
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreFocus());
  }

  void _open(String path) {
    _hadFocus = _listFocus.hasFocus;
    _cameFrom = _path;
    setState(() => _path = path);
    _load();
  }

  /// The listing replaces the focused row; focus the first folder of the new
  /// one, or the folder just left when going up.
  Future<void> _restoreFocus() async {
    if (!mounted || _folders.isEmpty) return;
    if (!fileManagerFocusLost(_listFocus) &&
        !(_hadFocus && _listFocus.hasFocus)) {
      return;
    }
    final path = _path;
    final index = _folders.indexWhere((folder) => folder.path == _cameFrom);
    final target = _folders[index == -1 ? 0 : index].path;
    if (fileManagerRevealRow(
      _scrollController,
      index == -1 ? 0 : index,
      _folders.length,
    )) {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || _path != path) return;
    }
    fileManagerFocusWhere(
      _listFocus,
      (context) =>
          context.findAncestorWidgetOfExactType<_FolderRow>()?.path == target,
    );
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
              child: Focus(
                focusNode: _listFocus,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _folders.isEmpty
                    ? Center(child: Text(l10n.fileManagerEmptyFolder))
                    : ListView.builder(
                        controller: _scrollController,
                        itemCount: _folders.length,
                        prototypeItem: const _FolderRow(path: '/'),
                        itemBuilder: (context, index) => _FolderRow(
                          path: _folders[index].path,
                          onTap: _open,
                        ),
                      ),
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

class _FolderRow extends StatelessWidget {
  final String path;
  final ValueChanged<String>? onTap;

  const _FolderRow({required this.path, this.onTap});

  @override
  Widget build(BuildContext context) {
    final tap = onTap;
    return ListTile(
      dense: true,
      leading: const Icon(Icons.folder_outlined),
      title: Text(
        p.basename(path),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: tap == null ? null : () => tap(path),
    );
  }
}
