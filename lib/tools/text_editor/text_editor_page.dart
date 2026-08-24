import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart' show XFile;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:tool_lab/core/shared_file.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/helpers/clipboard_helper.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import 'package:tool_lab/helpers/temp_file_manager.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/services/sharing_service.dart';
import 'package:tool_lab/tools/text_editor/config.dart';
import 'package:tool_lab/tools/text_editor/text_editor_state.dart';
import 'package:tool_lab/tools/text_editor/widgets/recent_files_list.dart';
import 'package:tool_lab/tools/text_editor/widgets/text_editor_settings_button.dart';
import 'package:tool_lab/tools/text_editor/widgets/text_editor_status_bar.dart';
import 'package:tool_lab/tools/text_editor/widgets/text_editor_surface.dart';
import 'package:tool_lab/tools/text_editor/widgets/text_editor_toolbar.dart';
import 'package:tool_lab/widgets/file_drop_zone.dart';
import 'package:tool_lab/widgets/file_name_dialog.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';
import 'package:tool_lab/widgets/tool_layout.dart';

class TextEditorToolPage extends StatefulWidget {
  final SharedFile? sharedFile;

  const TextEditorToolPage({super.key, this.sharedFile});

  @override
  State<TextEditorToolPage> createState() => _TextEditorToolPageState();
}

class _TextEditorToolPageState extends State<TextEditorToolPage>
    with DisposeCleanup {
  late final TempFileScope _scope;
  late final TextEditorState _state;
  bool _toolsExpanded = true;

  /// Keeps a single editor element alive across rebuilds; re_editor fires
  /// controller notifications from its own initState, and an overlapping old
  /// element would call setState mid-build.
  final GlobalKey _surfaceKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _scope = TempFileManager.createScope();
    onDispose(() => _scope.cleanTracked());

    _state = context.read<TextEditorState>();
    onDispose(() => _state.closeDocument(notify: false));

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _state.initialize();
      if (widget.sharedFile != null) {
        await _state.loadSharedFile(widget.sharedFile!);
      }
    });

    final sharingSub = SharingService.instance.onSharedFile.listen((file) {
      _handleIncomingShare(file);
    });
    onDispose(sharingSub.cancel);
  }

  /// A share intent arriving while an unsaved document is open must not
  /// silently discard it.
  Future<void> _handleIncomingShare(SharedFile file) async {
    if (_state.dirty) {
      final ok = await _confirmLeave();
      if (!ok || !mounted) return;
    }
    await _state.loadSharedFile(file);
  }

  Future<void> _openDropped(XFile file) => _state.openLocalPath(file.path);

  Future<void> _openRecent(TextEditorRecentFile recent) async {
    final opened = await _state.openRecent(recent);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).textEditorReopenFailed),
        ),
      );
    }
  }

  Future<void> _pasteClipboard() async {
    final l10n = AppLocalizations.of(context);
    final text = await ClipboardHelper.getText();
    if (!mounted) return;
    if (text == null || text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.textEditorClipboardEmpty)));
      return;
    }
    _state.startBlank(name: 'pasted.txt', content: text, dirty: true);
  }

  void _toggleFind() {
    if (_state.findController.value == null) {
      _state.findController.findMode();
      _state.findController.focusOnFindInput();
    } else {
      _state.findController.close();
    }
  }

  Future<bool> _confirmLeave() async {
    if (!_state.dirty) return true;
    if (!mounted) return false;
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<_LeaveDecision>(
      context: context,
      builder: (context) => ResponsiveAlertDialog(
        title: Text(l10n.textEditorUnsavedTitle),
        content: Text(l10n.textEditorUnsavedMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _LeaveDecision.cancel),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _LeaveDecision.discard),
            child: Text(l10n.textEditorDiscardChanges),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, _LeaveDecision.save),
            child: Text(l10n.textEditorSaveAndClose),
          ),
        ],
      ),
    );
    if (result == _LeaveDecision.save) {
      if (_state.filePath == null) {
        await _saveAs();
        // Still dirty when the picker was cancelled.
        return !_state.dirty;
      }
      return _state.save();
    }
    return result == _LeaveDecision.discard;
  }

  /// New documents have no backing file yet; saving them opens the picker.
  Future<void> _save() async {
    if (_state.isSaving) return;
    if (_state.filePath == null) return _saveAs();
    await _state.save();
  }

  Future<void> _requestPop() async {
    if (await _confirmLeave()) {
      if (mounted) context.pop();
    }
  }

  /// Closing returns to the file chooser; popping the route would dead-end in
  /// a standalone single-tool launch, which has nothing to pop to.
  Future<void> _closeDocument() async {
    if (await _confirmLeave()) _state.closeDocument();
  }

  Future<void> _saveAs() async {
    final l10n = AppLocalizations.of(context);
    var name = _state.fileName ?? 'untitled.txt';
    // Android exports straight into Downloads without a name prompt of its
    // own; desktop gets the native Save As dialog instead.
    if (Platform.isAndroid) {
      final chosen = await showDialog<String>(
        context: context,
        builder: (context) => FileNameDialog(
          title: l10n.textEditorFileNameTitle,
          initialValue: name,
        ),
      );
      if (chosen == null || !mounted) return;
      name = chosen;
    }
    final bytes = Uint8List.fromList(utf8.encode(_state.controller.text));
    final destPath = await FileSaveHelper.saveFile(
      context: context,
      suggestedName: name,
      bytes: bytes,
      successMessageGeneralBuilder: (displayPath) =>
          l10n.textEditorSavedTo(displayPath),
    );
    if (destPath != null) {
      await _state.adoptSavedPath(destPath, p.basename(destPath));
    }
  }

  Future<void> _share() async {
    final path = await _scope.createFile(
      _state.fileName ?? 'untitled.txt',
      bytes: Uint8List.fromList(utf8.encode(_state.controller.text)),
    );
    if (!mounted) return;
    await FileSaveHelper.showShareChooser(
      context: context,
      path: path,
      mimeType: 'text/plain',
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<TextEditorState>();
    final accent = TextEditorTool.config.accentColor;

    if (!state.initialized || (state.isLoading && state.filePath == null)) {
      return Scaffold(
        appBar: AppBar(
          title: Text(TextEditorTool.config.localizedName(l10n)),
          actions: [const TextEditorSettingsButton()],
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (state.filePath == null && state.fileName == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(TextEditorTool.config.localizedName(l10n)),
          actions: [const TextEditorSettingsButton()],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: FileDropZone(
                    tempScope: _scope,
                    onFileSelected: _openDropped,
                    allowedExtensions: TextEditorTool.config.fileExtensions,
                    typeLabel: l10n.textEditorTypeLabel,
                    accentColor: accent,
                    title: l10n.textEditorOpenTitle,
                    subtitle: l10n.textEditorDropSubtitle,
                    icon: Icons.article_outlined,
                    extraButtons: [
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => state.startBlank(),
                            icon: const Icon(Icons.edit_note),
                            label: Text(l10n.textEditorNewBlank),
                          ),
                          OutlinedButton.icon(
                            onPressed: _pasteClipboard,
                            icon: const Icon(Icons.paste),
                            label: Text(l10n.textEditorPasteClipboard),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                RecentFilesList(state: state, onOpen: _openRecent),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      );
    }

    return PopScope(
      canPop: !state.dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestPop();
      },
      child: ToolLayout(
        title:
            '${state.dirty ? '• ' : ''}${state.fileName ?? TextEditorTool.config.localizedName(l10n)}',
        actions: [
          IconButton(
            tooltip: l10n.commonSave,
            onPressed: state.isSaving ? null : _save,
            icon: const Icon(Icons.save_outlined),
          ),
          IconButton(
            tooltip: l10n.textEditorFind,
            onPressed: _toggleFind,
            icon: const Icon(Icons.search),
          ),
          IconButton(
            tooltip: l10n.textEditorTools,
            onPressed: () => setState(() => _toolsExpanded = !_toolsExpanded),
            icon: AnimatedRotation(
              turns: _toolsExpanded ? 0.0 : -0.25,
              duration: const Duration(milliseconds: 200),
              child: const Icon(Icons.expand_more),
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) => switch (value) {
              'settings' => context.push(
                '${TextEditorTool.config.route}/settings',
              ),
              'save-as' => _saveAs(),
              'share' => _share(),
              'close' => _closeDocument(),
              _ => {},
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'save-as',
                child: Text(l10n.textEditorSaveAs),
              ),
              PopupMenuItem(value: 'share', child: Text(l10n.commonShare)),
              PopupMenuItem(
                value: 'settings',
                child: Text(l10n.textEditorSettings),
              ),
              PopupMenuItem(value: 'close', child: Text(l10n.commonClose)),
            ],
          ),
        ],
        child: CallbackShortcuts(
          bindings: {
            SingleActivator(LogicalKeyboardKey.keyS, control: true, meta: true):
                _save,
            SingleActivator(LogicalKeyboardKey.keyF, control: true, meta: true):
                _toggleFind,
          },
          child: Column(
            children: [
              TextEditorToolbar(state: state, expanded: _toolsExpanded),
              const Divider(height: 1),
              Expanded(
                child: TextEditorSurface(key: _surfaceKey, state: state),
              ),
              DefaultTextStyle.merge(
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                child: TextEditorStatusBar(state: state),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _LeaveDecision { save, discard, cancel }
