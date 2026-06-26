import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_selector/file_selector.dart' show XFile;
import 'package:tool_lab/core/shared_file.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/services/sharing_service.dart';
import 'package:tool_lab/widgets/tool_layout.dart';
import 'package:tool_lab/widgets/file_drop_zone.dart';
import 'package:tool_lab/widgets/confirm_action_dialog.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/helpers/temp_file_manager.dart';

import 'config.dart';
import 'hex_editor_state.dart';
import 'widgets/hex_editor_toolbar.dart';
import 'widgets/hex_editor_display.dart';

class HexEditorPage extends StatefulWidget {
  final SharedFile? sharedFile;

  const HexEditorPage({super.key, this.sharedFile});

  @override
  State<HexEditorPage> createState() => _HexEditorPageState();
}

class _HexEditorPageState extends State<HexEditorPage> with DisposeCleanup {
  late final TempFileScope _scope;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scope = TempFileManager.createScope();
    onDispose(() => _scope.cleanTracked());
    onDispose(_scrollController.dispose);

    final state = context.read<HexEditorState>();
    onDispose(state.closeFile);

    // Load initial file if provided
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.sharedFile != null) {
        _loadSharedFile(widget.sharedFile!);
      }
    });

    // Listen for incoming files at runtime
    final sharingSub = SharingService.instance.onSharedFile.listen((file) {
      _loadSharedFile(file);
    });
    onDispose(sharingSub.cancel);
  }

  void _loadSharedFile(SharedFile file) {
    context.read<HexEditorState>().loadFile(file.path, file.name);
  }

  Future<void> _onFileSelected(XFile file) async {
    context.read<HexEditorState>().loadFile(file.path, file.name);
  }

  Future<bool> _confirmDiscardEdits() async {
    final state = context.read<HexEditorState>();
    if (!state.hasModifications) return true;

    final l10n = AppLocalizations.of(context);
    final discard = await ConfirmActionDialog.show(
      context: context,
      title: l10n.hexEditorDiscardChangesTitle,
      message: l10n.hexEditorDiscardChangesMessage,
      confirmLabel: l10n.hexEditorDiscard,
      cancelLabel: l10n.hexEditorKeepEditing,
    );
    return discard ?? false;
  }

  Future<void> _onClose() async {
    final state = context.read<HexEditorState>();
    final navigator = Navigator.of(context);
    final canPop = navigator.canPop();

    if (await _confirmDiscardEdits()) {
      await state.closeFile();
      if (widget.sharedFile != null && canPop) {
        navigator.pop();
      }
    }
  }

  void _navigateToOffset(int offset) {
    if (!_scrollController.hasClients) return;
    final rowIndex = offset ~/ 16;
    const double rowHeight = 28.0;
    final viewportHeight = _scrollController.position.viewportDimension;
    final targetScroll = max(0.0, rowIndex * rowHeight - viewportHeight / 2);
    _scrollController.jumpTo(targetScroll);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = context.watch<HexEditorState>();

    if (state.filePath == null) {
      return Scaffold(
        appBar: AppBar(title: Text(HexEditorTool.config.localizedName(l10n))),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: FileDropZone(
            onFileSelected: _onFileSelected,
            allowedExtensions: const [], // accept all extensions
            typeLabel: l10n.hexEditorTypeLabel,
            accentColor: HexEditorTool.config.accentColor,
            title: l10n.hexEditorOpenTitle,
            subtitle: l10n.hexEditorDropSubtitle,
            icon: Icons.developer_mode_outlined,
          ),
        ),
      );
    }

    final selected = state.selectedOffset;
    final offsetStr = selected != null
        ? '0x${selected.toRadixString(16).padLeft(8, '0').toUpperCase()} ($selected)'
        : '-';

    return PopScope(
      canPop: !state.hasModifications,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        final discard = await _confirmDiscardEdits();
        if (!mounted || !discard) return;
        navigator.pop();
      },
      child: ToolLayout(
        title: HexEditorTool.config.localizedName(l10n),
        fullscreen: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: l10n.commonExport,
            onPressed: () => state.exportFile(context, _scope),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: l10n.commonClose,
            onPressed: _onClose,
          ),
        ],
        child: Column(
          children: [
            HexEditorToolbar(
              onReset: _onClose,
              onNavigateToOffset: _navigateToOffset,
            ),
            const Divider(height: 1),
            Expanded(
              child: HexEditorDisplay(scrollController: _scrollController),
            ),
            const Divider(height: 1),
            // Bottom status bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.2,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${l10n.hexEditorOffset}: $offsetStr',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                  Row(
                    children: [
                      if (state.hasModifications) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.statusOrange.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: AppTheme.statusOrange,
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            l10n.hexEditorModified,
                            style: TextStyle(
                              color: AppTheme.statusOrange,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        l10n.hexEditorSize(state.totalSize.toString()),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
