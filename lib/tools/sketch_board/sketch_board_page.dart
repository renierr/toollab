import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/shared_file.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import 'package:tool_lab/helpers/temp_file_manager.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/providers/app_state.dart';
import 'package:tool_lab/helpers/clipboard_helper.dart';
import 'package:tool_lab/widgets/confirm_action_dialog.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';
import 'package:tool_lab/widgets/tool_layout.dart';
import 'package:file_selector/file_selector.dart';

import 'config.dart';
import 'geometry/sketch_export.dart';
import 'models/drawing_record.dart';
import 'models/sketch_enums.dart';
import 'sketch_board_state.dart';
import 'sketch_board_sync_delegate.dart';
import 'widgets/sketch_draw_tab.dart';
import 'widgets/sketch_export_dialog.dart';
import 'widgets/sketch_gallery.dart';
import 'widgets/sketch_redo_button.dart';
import 'widgets/sketch_text_editor.dart';
import 'widgets/sketch_undo_button.dart';
import '../../widgets/data_row.dart';
import 'geometry/element_bounds.dart';
import 'models/sketch_element.dart';

class SketchBoardPage extends StatefulWidget {
  final SharedFile? sharedFile;

  const SketchBoardPage({super.key, this.sharedFile});

  @override
  State<SketchBoardPage> createState() => _SketchBoardPageState();
}

class _SketchBoardPageState extends State<SketchBoardPage>
    with DisposeCleanup, SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final TabController _tabController;
  late final TempFileScope _tempScope;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tempScope = TempFileManager.createScope();
    onDispose(_tabController.dispose);
    onDispose(() => _tempScope.cleanTracked());

    final state = context.read<SketchBoardState>();
    state.onRequestText = _openTextEditor;
    onDispose(() => state.onRequestText = null);
    onDispose(() => state.clearMemory(notify: false));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = context.read<AppState>();
      if (appState.syncEnabled && appState.syncServerUrl.isNotEmpty) {
        appState
            .syncWithBackend([SketchBoardSyncDelegate()])
            .then((_) {
              if (mounted) context.read<SketchBoardState>().refreshSaved();
            })
            .catchError((e) {
              debugPrint('[SketchBoardPage] Auto-sync on open failed: $e');
            });
      }

      if (widget.sharedFile != null) {
        state.newDrawing();
        final file = File(widget.sharedFile!.path);
        file
            .readAsBytes()
            .then((bytes) {
              if (mounted) {
                state.addImage(bytes, mime: widget.sharedFile!.mimeType);
              }
            })
            .catchError((e) {
              debugPrint('Failed to load shared image: $e');
            });
      }
    });
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _fileName({String ext = 'png'}) =>
      'sketch-${DateTime.now().millisecondsSinceEpoch}.$ext';

  Future<void> _openTextEditor() async {
    final state = context.read<SketchBoardState>();
    final initial = state.editingText?.text ?? '';
    final result = await showSketchTextDialog(context, initial);
    if (result == null) {
      state.cancelText();
    } else {
      state.commitText(result);
    }
  }

  Future<Uint8List?> _renderPng() {
    final state = context.read<SketchBoardState>();
    return renderPng(state.elements);
  }

  Future<void> _exportPng() async {
    final state = context.read<SketchBoardState>();
    if (state.isEmpty) {
      _toast(AppLocalizations.of(context).sketchNothingToExport);
      return;
    }
    final bounds = sceneBounds(state.elements, padding: 8);
    if (bounds == null) {
      _toast(AppLocalizations.of(context).sketchNothingToExport);
      return;
    }
    Future<Uint8List?> render(ExportFormat format, int quality, double scale) {
      return renderImage(
        state.elements,
        format: format,
        quality: quality,
        scale: scale,
        background: format.isLossy ? state.backgroundColor : null,
      );
    }

    final options = await showSketchExportDialog(
      context,
      bounds.size,
      (format, quality, scale) async =>
          (await render(format, quality, scale))?.length,
    );
    if (options == null || !mounted) return;
    final bytes = await render(options.format, options.quality, options.scale);
    if (!mounted) return;
    if (bytes == null) {
      _toast(AppLocalizations.of(context).sketchNothingToExport);
      return;
    }
    final l10n = AppLocalizations.of(context);
    await FileSaveHelper.saveFile(
      context: context,
      suggestedName: _fileName(ext: options.format.extension),
      bytes: bytes,
      acceptedTypeGroups: [
        XTypeGroup(
          label: l10n.sketchExportLabelImage(options.format.label),
          extensions: [options.format.extension],
        ),
      ],
      successMessageAndroid: l10n.sigSavedToDownloads,
    );
  }

  Future<void> _copy() async {
    final bytes = await _renderPng();
    if (!mounted) return;
    if (bytes == null) {
      _toast(AppLocalizations.of(context).sketchNothingToExport);
      return;
    }
    final success = await ClipboardHelper.copyImageBytes(bytes);
    if (!mounted) return;
    if (success) {
      _toast(AppLocalizations.of(context).sketchCopied);
    } else {
      _toast(AppLocalizations.of(context).sketchCopyFailed);
    }
  }

  Future<void> _share() async {
    final bytes = await _renderPng();
    if (bytes == null || !mounted) {
      if (mounted) _toast(AppLocalizations.of(context).sketchNothingToExport);
      return;
    }
    final path = await _tempScope.createFile(_fileName(), bytes: bytes);
    if (!mounted) return;
    await FileSaveHelper.showShareChooser(
      context: context,
      path: path,
      mimeType: 'image/png',
    );
  }

  String _mimeFor(String name) {
    final n = name.toLowerCase();
    if (n.endsWith('.jpg') || n.endsWith('.jpeg')) return 'image/jpeg';
    if (n.endsWith('.gif')) return 'image/gif';
    if (n.endsWith('.webp')) return 'image/webp';
    if (n.endsWith('.bmp')) return 'image/bmp';
    return 'image/png';
  }

  Future<void> _insertImage() async {
    final l10n = AppLocalizations.of(context);
    final file = await openFile(
      acceptedTypeGroups: [
        XTypeGroup(
          label: l10n.sketchImageLabel,
          extensions: ['png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'],
        ),
      ],
    );
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    await context.read<SketchBoardState>().addImage(
      bytes,
      mime: _mimeFor(file.name),
    );
  }

  Future<void> _pasteImage() async {
    final bytes = await ClipboardHelper.getImagePng();
    if (!mounted) return;
    if (bytes == null) {
      _toast(AppLocalizations.of(context).sketchNoClipboardImage);
      return;
    }
    await context.read<SketchBoardState>().addImage(bytes);
  }

  Future<void> _save() async {
    final state = context.read<SketchBoardState>();
    if (state.isEmpty) {
      _toast(AppLocalizations.of(context).sketchNothingToExport);
      return;
    }
    final l10n = AppLocalizations.of(context);
    final defaultName = l10n.sketchDefaultName(
      DateTime.now().toString().split('.').first,
    );
    final name = await showSketchNameDialog(context, defaultName);
    if (name == null || name.trim().isEmpty || !mounted) return;
    final ok = await state.save(name.trim());
    if (ok && mounted) _toast(l10n.sketchSaved);
  }

  Future<void> _confirmClear() async {
    final l10n = AppLocalizations.of(context);
    final state = context.read<SketchBoardState>();
    if (state.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => ResponsiveAlertDialog(
        title: Text(l10n.sketchClearTitle),
        content: Text(l10n.sketchClearContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.commonClear),
          ),
        ],
      ),
    );
    if (ok == true && mounted) state.clear();
  }

  Future<void> _pickBackground() async {
    final l10n = AppLocalizations.of(context);
    final state = context.read<SketchBoardState>();
    final bg = await showDialog<CanvasBackground>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.sketchBackgroundTitle),
        children: [
          RadioGroup<CanvasBackground>(
            groupValue: state.background,
            onChanged: (v) => Navigator.of(ctx).pop(v),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final entry in <(CanvasBackground, String)>[
                  (CanvasBackground.checkerboard, l10n.sketchBgCheckerboard),
                  (CanvasBackground.white, l10n.sketchBgWhite),
                  (CanvasBackground.black, l10n.sketchBgBlack),
                ])
                  RadioListTile<CanvasBackground>(
                    value: entry.$1,
                    title: Text(entry.$2),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (bg != null) state.setBackground(bg);
  }

  void _showBoardInfo() {
    final state = context.read<SketchBoardState>();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final viewportStr =
        '${state.viewSize.width.round()} x ${state.viewSize.height.round()} px';

    final bounds = sceneBounds(state.elements);
    final boundsStr = bounds != null
        ? '${bounds.width.round()} x ${bounds.height.round()} px'
        : '-';

    final totalCount = state.elements.length;

    final penCount = state.elements.whereType<FreehandElement>().length;
    final shapeCount = state.elements.whereType<ShapeElement>().length;
    final textCount = state.elements.whereType<TextElement>().length;
    final imageCount = state.elements.whereType<ImageElement>().length;
    final groupCount = state.elements.whereType<GroupElement>().length;

    final zoomStr = '${(state.scale * 100).round()}%';
    final cameraStr =
        'x: ${state.offset.dx.round()}, y: ${state.offset.dy.round()}';
    final unsavedStr = state.hasUnsavedChanges ? l10n.commonYes : l10n.commonNo;

    showDialog<void>(
      context: context,
      builder: (ctx) => ResponsiveAlertDialog(
        title: Text(l10n.sketchInfoTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InfoRow(label: l10n.sketchInfoViewportSize, value: viewportStr),
            const SizedBox(height: 8),
            InfoRow(label: l10n.sketchInfoContentBounds, value: boundsStr),
            const SizedBox(height: 8),
            InfoRow(label: l10n.sketchInfoTotalElements, value: '$totalCount'),
            const SizedBox(height: 8),
            InfoRow(label: l10n.sketchInfoZoomLevel, value: zoomStr),
            const SizedBox(height: 8),
            InfoRow(label: l10n.sketchInfoViewOffset, value: cameraStr),
            const SizedBox(height: 8),
            InfoRow(label: l10n.sketchInfoUnsavedChanges, value: unsavedStr),
            if (totalCount > 0) ...[
              const SizedBox(height: 16),
              Divider(color: theme.colorScheme.outline.withValues(alpha: 0.15)),
              const SizedBox(height: 12),
              Text(
                l10n.sketchInfoElementsBreakdown,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              if (penCount > 0) ...[
                InfoRow(label: l10n.sketchInfoPenElements, value: '$penCount'),
                const SizedBox(height: 6),
              ],
              if (shapeCount > 0) ...[
                InfoRow(
                  label: l10n.sketchInfoShapeElements,
                  value: '$shapeCount',
                ),
                const SizedBox(height: 6),
              ],
              if (textCount > 0) ...[
                InfoRow(
                  label: l10n.sketchInfoTextElements,
                  value: '$textCount',
                ),
                const SizedBox(height: 6),
              ],
              if (imageCount > 0) ...[
                InfoRow(
                  label: l10n.sketchInfoImageElements,
                  value: '$imageCount',
                ),
                const SizedBox(height: 6),
              ],
              if (groupCount > 0) ...[
                InfoRow(
                  label: l10n.sketchInfoGroupElements,
                  value: '$groupCount',
                ),
                const SizedBox(height: 6),
              ],
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(MaterialLocalizations.of(ctx).okButtonLabel),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmDiscard() async {
    final state = context.read<SketchBoardState>();
    if (!state.hasUnsavedChanges) return true;
    final l10n = AppLocalizations.of(context);
    final discard = await ConfirmActionDialog.show(
      context: context,
      title: l10n.sketchDiscardTitle,
      message: l10n.sketchDiscardMessage,
      confirmLabel: l10n.sketchDiscard,
      cancelLabel: l10n.sketchKeepEditing,
    );
    return discard ?? false;
  }

  Future<void> _loadRecord(DrawingRecord record) async {
    if (!await _confirmDiscard() || !mounted) return;
    context.read<SketchBoardState>().loadRecord(record);
    _tabController.animateTo(0);
  }

  Future<void> _deleteRecord(DrawingRecord record) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => ResponsiveAlertDialog(
        title: Text(l10n.sketchDeleteTitle),
        content: Text(l10n.sketchDeleteContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<SketchBoardState>().deleteSaved(record.shortId);
  }

  Future<void> _triggerSync() async {
    final l10n = AppLocalizations.of(context);
    final appState = context.read<AppState>();
    if (appState.syncServerUrl.isEmpty) {
      _toast(l10n.notesSyncConfigureServerUrl);
      return;
    }
    try {
      final results = await appState.syncWithBackend([
        SketchBoardSyncDelegate(),
      ]);
      if (results != null) {
        if (mounted) {
          context.read<SketchBoardState>().refreshSaved();
          _toast(
            l10n.notesSyncFinished(
              results['pulled'] ?? 0,
              results['pushed'] ?? 0,
              results['deleted'] ?? 0,
            ),
          );
        }
      } else if (mounted) {
        _toast(l10n.notesSyncFailedEmpty);
      }
    } catch (e) {
      if (mounted) _toast(l10n.notesSyncFailed(e.toString()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isNarrow = MediaQuery.of(context).size.width < 480;
    final appState = context.watch<AppState>();

    return Selector<SketchBoardState, bool>(
      selector: (_, s) => s.hasUnsavedChanges,
      builder: (context, dirty, child) => PopScope(
        canPop: !dirty,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          final navigator = Navigator.of(context);
          final state = context.read<SketchBoardState>();
          if (await _confirmDiscard() && mounted) {
            state.discardChanges();
            navigator.pop();
          }
        },
        child: child!,
      ),
      child: ToolLayout(
        scaffoldKey: _scaffoldKey,
        title: SketchBoardTool.config.localizedName(l10n),
        actions: [
          if (appState.syncEnabled && appState.syncServerUrl.isNotEmpty)
            IconButton(
              tooltip: l10n.chipSyncTooltip,
              icon: appState.isSyncing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync),
              onPressed: appState.isSyncing ? null : _triggerSync,
            ),
          const SketchUndoButton(),
          const SketchRedoButton(),
          if (!isNarrow) ...[
            IconButton(
              tooltip: l10n.sketchInsertImage,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              onPressed: _insertImage,
            ),
            IconButton(
              tooltip: l10n.commonSave,
              icon: const Icon(Icons.save_outlined),
              onPressed: _save,
            ),
          ],
          PopupMenuButton<String>(
            onSelected: (v) {
              switch (v) {
                case 'insert-image':
                  _insertImage();
                case 'save':
                  _save();
                case 'paste-image':
                  _pasteImage();
                case 'export':
                  _exportPng();
                case 'copy':
                  _copy();
                case 'share':
                  _share();
                case 'background':
                  _pickBackground();
                case 'reset':
                  context.read<SketchBoardState>().resetView();
                case 'info':
                  _showBoardInfo();
                case 'clear':
                  _confirmClear();
              }
            },
            itemBuilder: (context) => [
              if (isNarrow) ...[
                PopupMenuItem(
                  value: 'insert-image',
                  child: Row(
                    children: [
                      const Icon(Icons.add_photo_alternate_outlined, size: 20),
                      const SizedBox(width: 10),
                      Text(l10n.sketchInsertImage),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'save',
                  child: Row(
                    children: [
                      const Icon(Icons.save_outlined, size: 20),
                      const SizedBox(width: 10),
                      Text(l10n.commonSave),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
              ],
              PopupMenuItem(
                value: 'paste-image',
                child: Row(
                  children: [
                    const Icon(Icons.content_paste_outlined, size: 20),
                    const SizedBox(width: 10),
                    Text(l10n.sketchPasteImage),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    const Icon(Icons.file_download_outlined, size: 20),
                    const SizedBox(width: 10),
                    Text(l10n.commonExport),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'copy',
                child: Row(
                  children: [
                    const Icon(Icons.content_copy_outlined, size: 20),
                    const SizedBox(width: 10),
                    Text(l10n.commonCopy),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    const Icon(Icons.share_outlined, size: 20),
                    const SizedBox(width: 10),
                    Text(l10n.commonShare),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'background',
                child: Row(
                  children: [
                    const Icon(Icons.grid_on_outlined, size: 20),
                    const SizedBox(width: 10),
                    Text(l10n.sketchMenuBackground),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'reset',
                child: Row(
                  children: [
                    const Icon(Icons.zoom_out_map_outlined, size: 20),
                    const SizedBox(width: 10),
                    Text(l10n.sketchMenuResetView),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'info',
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 20),
                    const SizedBox(width: 10),
                    Text(l10n.sketchMenuInfo),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    const Icon(Icons.delete_sweep_outlined, size: 20),
                    const SizedBox(width: 10),
                    Text(l10n.commonClear),
                  ],
                ),
              ),
            ],
          ),
        ],
        child: Column(
          children: [
            TabBar(
              controller: _tabController,
              tabs: [
                Tab(text: l10n.sketchTabDraw),
                Tab(text: l10n.sketchTabSaved),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  const SketchDrawTab(),
                  SketchGallery(onLoad: _loadRecord, onDelete: _deleteRecord),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
