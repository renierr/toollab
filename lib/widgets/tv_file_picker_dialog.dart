import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/helpers/external_activity.dart';
import 'package:tool_lab/helpers/mime_type_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/providers/app_state.dart';
import 'package:tool_lab/services/tv_service.dart';
import 'package:tool_lab/tools/file_manager/file_manager_storage_access.dart';
import 'package:tool_lab/widgets/focus_outline.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

/// In-app local file chooser for Android TV (which lacks a system SAF
/// `ACTION_OPEN_DOCUMENT` activity).
class TvFilePickerDialog extends StatefulWidget {
  final String initialPath;
  final List<String> allowedExtensions;
  final List<String> allowedMimeTypes;
  final bool allowMultiple;

  const TvFilePickerDialog({
    super.key,
    required this.initialPath,
    this.allowedExtensions = const [],
    this.allowedMimeTypes = const [],
    this.allowMultiple = false,
  });

  /// Returns true when the current device/session should use the in-app TV
  /// file chooser instead of the platform SAF picker.
  static Future<bool> shouldUse(BuildContext context) async {
    if (!Platform.isAndroid) return false;
    final tvMode = Provider.of<AppState?>(context, listen: false)?.tvMode;
    if (tvMode == true) return true;
    return TvService.isTelevision();
  }

  /// Picks a single file, using [TvFilePickerDialog] on Android TV and falling
  /// back to the platform [openFile] picker everywhere else.
  static Future<XFile?> openSingleFile(
    BuildContext context, {
    List<XTypeGroup> acceptedTypeGroups = const [],
  }) async {
    if (await shouldUse(context)) {
      if (!context.mounted) return null;
      final files = await pick(
        context,
        acceptedTypeGroups: acceptedTypeGroups,
        allowMultiple: false,
      );
      return files.firstOrNull;
    }
    return ExternalActivity.run(
      () => openFile(acceptedTypeGroups: acceptedTypeGroups),
    );
  }

  /// Picks one or more files, using [TvFilePickerDialog] on Android TV and
  /// falling back to the platform [openFiles] picker everywhere else.
  static Future<List<XFile>> openMultipleFiles(
    BuildContext context, {
    List<XTypeGroup> acceptedTypeGroups = const [],
  }) async {
    if (await shouldUse(context)) {
      if (!context.mounted) return const [];
      return pick(
        context,
        acceptedTypeGroups: acceptedTypeGroups,
        allowMultiple: true,
      );
    }
    return ExternalActivity.run(
      () => openFiles(acceptedTypeGroups: acceptedTypeGroups),
    );
  }

  /// Opens a single-file or multi-file chooser dialog on Android TV.
  static Future<List<XFile>> pick(
    BuildContext context, {
    List<XTypeGroup> acceptedTypeGroups = const [],
    List<String> allowedExtensions = const [],
    List<String> allowedMimeTypes = const [],
    bool allowMultiple = false,
  }) async {
    final extensions = <String>{
      for (final ext in allowedExtensions) ext.toLowerCase(),
      for (final group in acceptedTypeGroups)
        for (final ext in group.extensions ?? const <String>[])
          ext.toLowerCase(),
    }.toList();
    final mimeTypes = <String>{
      for (final mime in allowedMimeTypes) mime.toLowerCase(),
      for (final group in acceptedTypeGroups)
        for (final mime in group.mimeTypes ?? const <String>[])
          mime.toLowerCase(),
    }.toList();

    final initialPath = await _resolveInitialPath();
    if (!context.mounted) return const [];
    final picked = await showDialog<List<XFile>>(
      context: context,
      builder: (_) => TvFilePickerDialog(
        initialPath: initialPath,
        allowedExtensions: extensions,
        allowedMimeTypes: mimeTypes,
        allowMultiple: allowMultiple,
      ),
    );
    return picked ?? const [];
  }

  static Future<String> _resolveInitialPath() async {
    if (await FileManagerStorageAccess.hasAllFilesAccess()) {
      final external = await FileManagerStorageAccess.externalStoragePath();
      if (external != null && await Directory(external).exists()) {
        return external;
      }
    }
    final docs = await getApplicationDocumentsDirectory();
    return docs.path;
  }

  @override
  State<TvFilePickerDialog> createState() => _TvFilePickerDialogState();
}

class _TvFilePickerDialogState extends State<TvFilePickerDialog>
    with WidgetsBindingObserver {
  late String _path = widget.initialPath;
  List<FileSystemEntity> _entries = const [];
  final Set<String> _selectedPaths = {};
  bool _isLoading = true;
  bool _hasAllFilesAccess = true;
  bool _awaitingStorageAccess = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAccessAndLoad();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _awaitingStorageAccess) {
      _awaitingStorageAccess = false;
      _checkAccessAndLoad(switchToRootIfGranted: true);
    }
  }

  Future<void> _checkAccessAndLoad({bool switchToRootIfGranted = false}) async {
    final hasAccess = await FileManagerStorageAccess.hasAllFilesAccess();
    if (!mounted) return;
    if (switchToRootIfGranted && hasAccess) {
      final external = await FileManagerStorageAccess.externalStoragePath();
      if (external != null) _path = external;
    }
    setState(() => _hasAllFilesAccess = hasAccess);
    await _load();
  }

  Future<void> _requestAllFilesAccess() async {
    _awaitingStorageAccess = true;
    await FileManagerStorageAccess.requestAllFilesAccess();
  }

  bool _matchesFilter(String filePath) {
    if (widget.allowedExtensions.isEmpty && widget.allowedMimeTypes.isEmpty) {
      return true;
    }
    final lowerName = p.basename(filePath).toLowerCase();
    for (final ext in widget.allowedExtensions) {
      if (lowerName.endsWith('.$ext')) return true;
    }
    if (widget.allowedMimeTypes.isNotEmpty) {
      final mime = MimeTypeHelper.getMimeType(lowerName).toLowerCase();
      for (final allowed in widget.allowedMimeTypes) {
        if (allowed == '*/*' || allowed == mime) return true;
        if (allowed.endsWith('/*')) {
          final prefix = allowed.substring(0, allowed.length - 1);
          if (mime.startsWith(prefix)) return true;
        }
      }
    }
    return false;
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final folders = <Directory>[];
    final files = <File>[];
    try {
      for (final entity in Directory(_path).listSync(followLinks: false)) {
        final name = p.basename(entity.path);
        if (name.startsWith('.')) continue;
        if (entity is Directory) {
          folders.add(entity);
        } else if (entity is File && _matchesFilter(entity.path)) {
          files.add(entity);
        }
      }
    } catch (_) {}

    int compareByName(FileSystemEntity a, FileSystemEntity b) => p
        .basename(a.path)
        .toLowerCase()
        .compareTo(p.basename(b.path).toLowerCase());
    folders.sort(compareByName);
    files.sort(compareByName);

    if (!mounted) return;
    setState(() {
      _entries = [...folders, ...files];
      _isLoading = false;
    });
  }

  void _openDirectory(String path) {
    setState(() => _path = path);
    _load();
  }

  XFile _toXFile(String path) {
    final name = p.basename(path);
    return XFile(path, name: name, mimeType: MimeTypeHelper.getMimeType(name));
  }

  void _activateFile(String path) {
    if (!widget.allowMultiple) {
      Navigator.of(context).pop([_toXFile(path)]);
      return;
    }
    setState(() {
      if (_selectedPaths.contains(path)) {
        _selectedPaths.remove(path);
      } else {
        _selectedPaths.add(path);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final parent = p.dirname(_path);
    final canGoUp = parent != _path;

    return ResponsiveAlertDialog(
      title: Text(l10n.commonBrowseFiles),
      content: SizedBox(
        width: 460,
        height: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_hasAllFilesAccess)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: FocusOutline(
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                  child: OutlinedButton.icon(
                    onPressed: _requestAllFilesAccess,
                    icon: const Icon(Icons.folder_open_outlined, size: 18),
                    label: Text(l10n.fileManagerAllFilesAccess),
                  ),
                ),
              ),
            Row(
              children: [
                FocusOutline(
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                  child: IconButton(
                    tooltip: l10n.commonBack,
                    onPressed: canGoUp ? () => _openDirectory(parent) : null,
                    icon: const Icon(Icons.arrow_upward),
                  ),
                ),
                const SizedBox(width: 4),
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
                  : _entries.isEmpty
                  ? Center(child: Text(l10n.fileManagerEmptyFolder))
                  : ListView.builder(
                      itemCount: _entries.length,
                      itemBuilder: (context, index) {
                        final entity = _entries[index];
                        final isDir = entity is Directory;
                        final name = p.basename(entity.path);
                        final selected = _selectedPaths.contains(entity.path);
                        return FocusOutline(
                          borderRadius: const BorderRadius.all(
                            Radius.circular(8),
                          ),
                          child: ListTile(
                            autofocus: index == 0,
                            dense: true,
                            selected: selected,
                            leading: Icon(
                              isDir
                                  ? Icons.folder_outlined
                                  : Icons.insert_drive_file_outlined,
                            ),
                            title: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: !isDir && widget.allowMultiple
                                ? Checkbox(
                                    value: selected,
                                    onChanged: (_) =>
                                        _activateFile(entity.path),
                                  )
                                : null,
                            onTap: () => isDir
                                ? _openDirectory(entity.path)
                                : _activateFile(entity.path),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        FocusOutline(
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.commonCancel),
          ),
        ),
        if (widget.allowMultiple)
          FocusOutline(
            borderRadius: const BorderRadius.all(Radius.circular(8)),
            child: FilledButton(
              onPressed: _selectedPaths.isEmpty
                  ? null
                  : () => Navigator.of(
                      context,
                    ).pop(_selectedPaths.map(_toXFile).toList()),
              child: Text(l10n.commonOpen),
            ),
          ),
      ],
    );
  }
}
