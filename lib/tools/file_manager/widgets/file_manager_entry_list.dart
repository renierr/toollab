import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/file_manager/file_manager_connection.dart';
import 'package:tool_lab/tools/file_manager/file_manager_entry.dart';
import 'package:tool_lab/tools/file_manager/file_manager_list_focus.dart';
import 'package:tool_lab/tools/file_manager/file_manager_state.dart';
import 'package:tool_lab/tools/file_manager/widgets/file_manager_entry_tile.dart';
import 'package:tool_lab/widgets/responsive_layout.dart';

/// The folder listing. Keeps the focus in the list across folder changes:
/// a new listing focuses its first row, or the folder just left.
class FileManagerEntryList extends StatefulWidget {
  final FileManagerState state;
  final ScrollController scrollController;
  final ValueChanged<FileManagerEntry> onOpen;
  final ValueChanged<FileManagerEntry> onOpenWithSystem;
  final ValueChanged<FileManagerEntry> onShare;
  final ValueChanged<FileManagerEntry> onDetails;
  final ValueChanged<FileManagerEntry> onRename;
  final ValueChanged<FileManagerEntry> onDelete;
  final ValueChanged<FileManagerEntry> onCopy;
  final ValueChanged<FileManagerEntry> onCut;
  final ValueChanged<FileManagerEntry> onExtract;
  final ValueChanged<FileManagerEntry> onToggleSelection;
  final ValueChanged<double>? onItemExtentChanged;

  /// Right on a row's trailing control, e.g. to reach the toolbar actions.
  final VoidCallback? onRight;

  const FileManagerEntryList({
    super.key,
    required this.state,
    required this.scrollController,
    required this.onOpen,
    required this.onOpenWithSystem,
    required this.onShare,
    required this.onDetails,
    required this.onRename,
    required this.onDelete,
    required this.onCopy,
    required this.onCut,
    required this.onExtract,
    required this.onToggleSelection,
    this.onItemExtentChanged,
    this.onRight,
  });

  @override
  State<FileManagerEntryList> createState() => _FileManagerEntryListState();
}

class _FileManagerEntryListState extends State<FileManagerEntryList>
    with DisposeCleanup {
  final FocusNode _listFocus = FocusNode(
    debugLabel: 'FileManagerEntryList',
    canRequestFocus: false,
    skipTraversal: true,
  );
  late String _path = widget.state.path;
  late int _listing = widget.state.listingGeneration;
  List<FileManagerEntry> _shown = const [];
  bool _awaitingListing = true;
  bool _hadFocus = false;
  String? _focusTarget;
  int _fallbackIndex = 0;

  @override
  void initState() {
    super.initState();
    onDispose(_listFocus.dispose);
  }

  @override
  void didUpdateWidget(FileManagerEntryList oldWidget) {
    super.didUpdateWidget(oldWidget);
    final state = widget.state;
    if (state.path == _path && state.listingGeneration == _listing) return;
    // The old rows are still mounted here, so the focus is still on them.
    final focused = _focusedEntry();
    final sameFolder = state.path == _path;
    _hadFocus = _listFocus.hasFocus;
    _focusTarget = sameFolder ? focused?.path : _path;
    _fallbackIndex = sameFolder && focused != null
        ? _shown.indexWhere((entry) => entry.path == focused.path)
        : 0;
    _path = state.path;
    _listing = state.listingGeneration;
    _awaitingListing = true;
  }

  FileManagerEntry? _focusedEntry({bool trailingOnly = false}) {
    final context = FocusManager.instance.primaryFocus?.context;
    if (context == null || !_listFocus.hasFocus) return null;
    if (trailingOnly &&
        context.findAncestorWidgetOfExactType<ListTile>() != null) {
      return null;
    }
    return context.findAncestorWidgetOfExactType<FileManagerEntryTile>()?.entry;
  }

  Future<void> _restoreFocus() async {
    final path = _path;
    final entries = widget.state.entries;
    if (!mounted || entries.isEmpty) return;
    if (!fileManagerFocusLost(_listFocus) &&
        !(_hadFocus && _listFocus.hasFocus)) {
      return;
    }
    var index = entries.indexWhere((entry) => entry.path == _focusTarget);
    if (index == -1) index = _fallbackIndex.clamp(0, entries.length - 1);
    final target = entries[index].path;
    if (fileManagerRevealRow(widget.scrollController, index, entries.length)) {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || widget.state.path != path) return;
    }
    fileManagerFocusWhere(
      _listFocus,
      (context) =>
          context.findAncestorWidgetOfExactType<ListTile>() != null &&
          context
                  .findAncestorWidgetOfExactType<FileManagerEntryTile>()
                  ?.entry
                  .path ==
              target,
    );
  }

  /// Down stays on the last row instead of jumping into the locations pane;
  /// right on a trailing control goes to [FileManagerEntryList.onRight].
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final onRight = widget.onRight;
    if (key == LogicalKeyboardKey.arrowRight &&
        onRight != null &&
        _focusedEntry(trailingOnly: true) != null) {
      if (event is KeyDownEvent) onRight();
      return KeyEventResult.handled;
    }
    final entries = widget.state.entries;
    if (key == LogicalKeyboardKey.arrowDown &&
        !widget.state.isLoading &&
        entries.isNotEmpty &&
        _focusedEntry()?.path == entries.last.path) {
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    _shown = state.entries;
    if (_awaitingListing && !state.isLoading) {
      _awaitingListing = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _restoreFocus());
    }
    if (state.isLoading && state.entries.isEmpty) {
      return Focus(
        focusNode: _listFocus,
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    final l10n = AppLocalizations.of(context);
    return Focus(
      focusNode: _listFocus,
      onKeyEvent: _onKey,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemExtent = constraints.isCompact ? 88.0 : 72.0;
          final notifyExtent = widget.onItemExtentChanged;
          if (notifyExtent != null) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => notifyExtent(itemExtent),
            );
          }
          if (state.entries.isEmpty) {
            return ListView(
              controller: widget.scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: constraints.maxHeight,
                  child: Center(child: Text(l10n.fileManagerEmptyFolder)),
                ),
              ],
            );
          }
          return ListView.builder(
            controller: widget.scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            itemExtent: itemExtent,
            itemCount: state.entries.length,
            itemBuilder: (context, index) {
              final entry = state.entries[index];
              return FileManagerEntryTile(
                entry: entry,
                onOpen: widget.onOpen,
                onOpenWithSystem: widget.onOpenWithSystem,
                onShare: widget.onShare,
                onDetails: widget.onDetails,
                onRename: widget.onRename,
                onDelete: widget.onDelete,
                onCopy: widget.onCopy,
                onCut: widget.onCut,
                onExtract: widget.onExtract,
                showClipboardActions:
                    state.connection?.protocol != FileManagerProtocol.ftp,
                selectionMode: state.isSelectionMode,
                selected: state.selectedPaths.contains(entry.path),
                onToggleSelection: widget.onToggleSelection,
                isInClipboard: state.clipboardPaths.contains(entry.path),
                clipboardIsCut: state.clipboardIsCut,
                readOnly: state.isReadOnly,
                showImagePreviews: !state.isRemote,
                metadata: state.metadataFor(entry),
                childCount: state.childCountFor(entry),
              );
            },
          );
        },
      ),
    );
  }
}
