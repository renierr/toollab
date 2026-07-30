import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart' show XFile;
import 'package:provider/provider.dart';

import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/core/shared_file.dart';
import 'package:tool_lab/helpers/clipboard_helper.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import 'package:tool_lab/helpers/mime_type_helper.dart';
import 'package:tool_lab/helpers/temp_file_manager.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/providers/app_state.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/tools/fast_drop/fast_drop_p2p_state.dart';
import 'package:tool_lab/tools/fast_drop/fast_drop_state.dart';
import 'package:tool_lab/widgets/confirm_action_dialog.dart';
import 'package:tool_lab/widgets/responsive_orientation_layout.dart';
import 'package:tool_lab/widgets/tool_layout.dart';
import 'package:tool_lab/widgets/tool_back_button.dart';

import 'config.dart';
import 'fast_drop_model.dart';
import 'p2p/p2p_models.dart';
import 'widgets/fast_drop_incoming_request_dialog.dart';
import 'widgets/fast_drop_mode_toggle.dart';
import 'widgets/fast_drop_p2p_view.dart';
import 'widgets/fast_drop_preview_dialog.dart';
import 'widgets/fast_drop_upload_panel.dart';
import 'widgets/fast_drop_status_banner.dart';
import 'widgets/fast_drop_pending_card.dart';
import 'widgets/fast_drop_list.dart';
import 'widgets/fast_drop_transfer_progress.dart';
import 'widgets/fast_drop_not_configured.dart';
import 'widgets/fast_drop_edit_description_dialog.dart';
import 'widgets/fast_drop_edit_retention_dialog.dart';

class FastDropPage extends StatefulWidget {
  final SharedData? sharedData;

  const FastDropPage({super.key, this.sharedData});

  @override
  State<FastDropPage> createState() => _FastDropPageState();
}

class _FastDropPageState extends State<FastDropPage> with DisposeCleanup {
  late final TempFileScope _scope = TempFileManager.createScope();
  String _retention = '24';
  List<SharedFile> _pendingSharedFiles = [];
  bool _isUploadingPending = false;
  FastDropMode _mode = FastDropMode.cloud;
  bool _incomingDialogOpen = false;

  String get _localDeviceName {
    try {
      return Platform.localHostname;
    } catch (_) {
      return 'ToolLab device';
    }
  }

  @override
  void initState() {
    super.initState();
    onDispose(() => _scope.cleanTracked());
    final p2p = context.read<FastDropP2pState>();
    onDispose(() {
      p2p.stopReceiving();
      p2p.stopScanningForPeers();
    });

    if (widget.sharedData != null) {
      _pendingSharedFiles = List<SharedFile>.from(widget.sharedData!.files);
    }

    DatabaseService.instance
        .getSetting(FastDropTool.config.id, 'retention')
        .then((val) {
          if (val != null && mounted) {
            setState(() {
              _retention = val;
            });
          }
        });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<FastDropState>().loadFastDrops();
      }
    });
  }

  @override
  void didUpdateWidget(covariant FastDropPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sharedData != oldWidget.sharedData &&
        widget.sharedData != null) {
      setState(() {
        _pendingSharedFiles = List<SharedFile>.from(widget.sharedData!.files);
      });
    }
  }

  void _onRetentionChanged(String val) {
    setState(() => _retention = val);
    DatabaseService.instance.setSetting(
      FastDropTool.config.id,
      'retention',
      val,
    );
  }

  Future<void> _pasteFromClipboard() async {
    final appState = context.read<AppState>();
    final fastDropState = context.read<FastDropState>();
    if (!appState.syncEnabled || !fastDropState.isServerAvailable) return;
    final l10n = AppLocalizations.of(context);
    try {
      final text = await ClipboardHelper.getText();
      if (text != null && text.trim().isNotEmpty) {
        final bytes = utf8.encode(text);
        final filename =
            'pasted-text-${DateTime.now().millisecondsSinceEpoch}.txt';
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.fastDropPastingText)));
        }
        final path = await _scope.createFile(filename, bytes: bytes);
        await fastDropState.uploadFastDrop(
          filename: filename,
          filePath: path,
          retention: _retention,
          source: 'clipboard',
          mimeType: 'text/plain',
        );
      } else {
        final imageBytes = await ClipboardHelper.getImagePng();
        if (imageBytes != null && imageBytes.isNotEmpty) {
          final filename =
              'pasted-image-${DateTime.now().millisecondsSinceEpoch}.png';
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(l10n.fastDropPastingImage)));
          }
          final path = await _scope.createFile(filename, bytes: imageBytes);
          await fastDropState.uploadFastDrop(
            filename: filename,
            filePath: path,
            retention: _retention,
            source: 'clipboard',
            mimeType: 'image/png',
          );
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.fastDropClipboardEmpty)),
            );
          }
          return;
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.fastDropUploadedSuccessfully)),
        );
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
    }
  }

  Future<void> _onFilesSelected(List<XFile> files) async {
    final appState = context.read<AppState>();
    final fastDropState = context.read<FastDropState>();
    if (!appState.syncEnabled || !fastDropState.isServerAvailable) return;
    final l10n = AppLocalizations.of(context);
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.fastDropUploadingFiles(files.length))),
        );
      }
      for (int i = 0; i < files.length; i++) {
        final file = files[i];
        if (mounted && files.length > 1) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                l10n.fastDropUploadingFileProgress(
                  i + 1,
                  files.length,
                  file.name,
                ),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        String mimeType = file.mimeType ?? 'application/octet-stream';
        if (mimeType == 'application/octet-stream' || mimeType.isEmpty) {
          mimeType = MimeTypeHelper.getMimeType(file.name);
        }
        try {
          await fastDropState.uploadFastDrop(
            filename: file.name,
            filePath: file.path,
            retention: _retention,
            source: 'file',
            mimeType: mimeType,
          );
        } finally {
          if (Platform.isAndroid) {
            final fileCopy = File(file.path);
            if (await fileCopy.exists()) await fileCopy.delete();
          }
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.fastDropUploadedSuccessfully)),
        );
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
    }
  }

  Future<void> _uploadPendingSharedFiles() async {
    if (_pendingSharedFiles.isEmpty) return;
    final appState = context.read<AppState>();
    final fastDropState = context.read<FastDropState>();
    if (!appState.syncEnabled || !fastDropState.isServerAvailable) return;
    final l10n = AppLocalizations.of(context);
    final filesToUpload = List<SharedFile>.from(_pendingSharedFiles);
    try {
      setState(() {
        _isUploadingPending = true;
      });
      for (int i = 0; i < filesToUpload.length; i++) {
        final file = filesToUpload[i];
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                l10n.fastDropUploadingFileProgress(
                  i + 1,
                  filesToUpload.length,
                  file.name,
                ),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        String mimeType = file.mimeType;
        if (mimeType == 'application/octet-stream' || mimeType.isEmpty) {
          mimeType = MimeTypeHelper.getMimeType(file.name);
        }
        await fastDropState.uploadFastDrop(
          filename: file.name,
          filePath: file.path,
          retention: _retention,
          source: 'file',
          mimeType: mimeType,
        );
      }
      setState(() {
        _pendingSharedFiles.clear();
        _isUploadingPending = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.fastDropSharedFilesUploaded)),
        );
      }
    } catch (e) {
      setState(() {
        _isUploadingPending = false;
      });
      if (mounted) {
        final msg = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
    }
  }

  Future<void> _onDelete(FastDropItem item) async {
    final l10n = AppLocalizations.of(context);
    final fastDropState = context.read<FastDropState>();
    final confirm = await ConfirmActionDialog.show(
      context: context,
      title: l10n.fastDropDeleteTitle,
      message: l10n.fastDropDeleteMessage(item.filename),
      confirmLabel: l10n.commonDelete,
    );
    if (confirm == true) {
      try {
        await fastDropState.deleteFastDrop(item.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.fastDropDeletedSuccessfully)),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.fastDropDeleteFailed(e.toString()))),
          );
        }
      }
    }
  }

  Future<void> _onDownload(FastDropItem item) async {
    final l10n = AppLocalizations.of(context);
    final fastDropState = context.read<FastDropState>();
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.fastDropDownloadingFile(item.filename))),
        );
      }
      final tempPath = await _scope.createFile('fast_drop_save_${item.id}');
      await fastDropState.downloadFastDropToFile(
        id: item.id,
        outputPath: tempPath,
        knownSize: item.size,
      );
      if (!mounted) return;
      await FileSaveHelper.saveFileFromPath(
        context: context,
        suggestedName: item.filename,
        sourcePath: tempPath,
      );
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
    }
  }

  Future<void> _onOpen(FastDropItem item) async {
    final l10n = AppLocalizations.of(context);
    final fastDropState = context.read<FastDropState>();
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.fastDropDownloadingFileToOpen(item.filename)),
          ),
        );
      }
      final tempPath = await _scope.createFile(
        'fast_drop_open_${item.id}_${item.filename}',
      );
      await fastDropState.downloadFastDropToFile(
        id: item.id,
        outputPath: tempPath,
        knownSize: item.size,
      );

      if (mounted) {
        await FileSaveHelper.showOpenChooser(
          context: context,
          path: tempPath,
          mimeType: item.type,
        );
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
    }
  }

  Future<void> _onUpdateDescription(FastDropItem item) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => FastDropEditDescriptionDialog(
        currentDescription: item.description ?? '',
      ),
    );
    if (result == null || !mounted) return;
    final l10n = AppLocalizations.of(context);
    try {
      await context.read<FastDropState>().updateFastDropDescription(
        item.id,
        result,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.fastDropDescriptionUpdated)),
        );
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
    }
  }

  Future<void> _onUpdateRetention(FastDropItem item) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => FastDropEditRetentionDialog(item: item),
    );
    if (result == null || !mounted) return;
    final l10n = AppLocalizations.of(context);
    try {
      await context.read<FastDropState>().updateFastDropRetention(
        item.id,
        result,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.fastDropRetentionUpdated)));
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
    }
  }

  void _onPreview(FastDropItem item) {
    showDialog(
      context: context,
      builder: (context) => FastDropPreviewDialog(
        item: item,
        onDownloadToFile: (id, outputPath) =>
            context.read<FastDropState>().downloadFastDropToFile(
              id: id,
              outputPath: outputPath,
              knownSize: item.size,
            ),
        onOpen: () => _onOpen(item),
        onSave: () => _onDownload(item),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Nearby (BLE/LAN) P2P mode
  // ---------------------------------------------------------------------

  Future<void> _onFilePickedToSend(List<XFile> files) async {
    if (files.isEmpty) return;
    final file = files.first;
    final p2p = context.read<FastDropP2pState>();
    try {
      String mimeType = file.mimeType ?? 'application/octet-stream';
      if (mimeType == 'application/octet-stream' || mimeType.isEmpty) {
        mimeType = MimeTypeHelper.getMimeType(file.name);
      }
      final size = await file.length();
      p2p.setPendingSendFile(
        path: file.path,
        name: file.name,
        size: size,
        mimeType: mimeType,
      );
      await p2p.startScanningForPeers();
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
    }
  }

  Future<void> _onPasteClipboardToSend() async {
    final p2p = context.read<FastDropP2pState>();
    final l10n = AppLocalizations.of(context);
    try {
      final text = await ClipboardHelper.getText();
      if (text != null && text.trim().isNotEmpty) {
        final bytes = utf8.encode(text);
        final filename =
            'pasted-text-${DateTime.now().millisecondsSinceEpoch}.txt';
        final path = await _scope.createFile(filename, bytes: bytes);
        p2p.setPendingSendFile(
          path: path,
          name: filename,
          size: bytes.length,
          mimeType: 'text/plain',
        );
        await p2p.startScanningForPeers();
        return;
      }

      final imageBytes = await ClipboardHelper.getImagePng();
      if (imageBytes != null && imageBytes.isNotEmpty) {
        final filename =
            'pasted-image-${DateTime.now().millisecondsSinceEpoch}.png';
        final path = await _scope.createFile(filename, bytes: imageBytes);
        p2p.setPendingSendFile(
          path: path,
          name: filename,
          size: imageBytes.length,
          mimeType: 'image/png',
        );
        await p2p.startScanningForPeers();
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.fastDropClipboardEmpty)));
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
    }
  }

  void _onCancelSendSelection() {
    final p2p = context.read<FastDropP2pState>();
    p2p.clearPendingSendFile();
    p2p.stopScanningForPeers();
  }

  Future<void> _onSelectPeer(P2pPeer peer) async {
    final p2p = context.read<FastDropP2pState>();
    await p2p.sendToPeer(peer, _localDeviceName);
  }

  Future<void> _onToggleReceiving() async {
    final p2p = context.read<FastDropP2pState>();
    if (p2p.role == P2pRole.receiving) {
      await p2p.stopReceiving();
    } else {
      await p2p.startReceiving(_localDeviceName);
    }
  }

  Future<void> _maybeShowIncomingRequestDialog(FastDropP2pState p2p) async {
    final incoming = p2p.incomingRequest;
    if (incoming == null || _incomingDialogOpen) return;
    _incomingDialogOpen = true;
    final (_, request) = incoming;
    final accept = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => FastDropIncomingRequestDialog(
        senderName: request.senderName,
        request: request,
      ),
    );
    _incomingDialogOpen = false;
    if (!mounted) return;
    if (accept == true) {
      try {
        final baseName =
            'p2p_received_${DateTime.now().millisecondsSinceEpoch}_${_safeTempFileName(request.fileName)}';
        final outputPath = await _scope.createFile(baseName);
        await p2p.acceptIncomingRequest(outputPath, tempFileBaseName: baseName);
      } catch (e) {
        if (mounted) {
          final message = e.toString().replaceAll('Exception: ', '');
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        }
      }
    } else {
      await p2p.rejectIncomingRequest();
    }
  }

  String _safeTempFileName(String filename) {
    final safeName = filename
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
        .trim();
    return safeName.isEmpty ? 'file' : safeName;
  }

  void _onDismissReceived(P2pReceivedFile file) {
    final p2p = context.read<FastDropP2pState>();
    p2p.dismissReceivedFile(file.id);
    unawaited(_scope.deleteFile(file.tempFileBaseName));
  }

  Future<void> _onOpenReceived(P2pReceivedFile file) async {
    if (!mounted) return;
    await FileSaveHelper.showOpenChooser(
      context: context,
      path: file.tempFileName,
      mimeType: file.mimeType,
    );
  }

  Future<void> _onSaveReceived(P2pReceivedFile file) async {
    if (!mounted) return;
    await FileSaveHelper.saveFileFromPath(
      context: context,
      suggestedName: file.filename,
      sourcePath: file.tempFileName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final appState = context.watch<AppState>();
    final fastDropState = context.read<FastDropState>();
    final (isLoadingFastDrops, isServerAvailable, _, _) = context
        .select<FastDropState, (bool, bool, String?, List<FastDropItem>)>(
          (state) => (
            state.isLoadingFastDrops,
            state.isServerAvailable,
            state.fastDropError,
            state.fastDrops,
          ),
        );
    final p2pState = context.watch<FastDropP2pState>();
    final theme = Theme.of(context);
    final isConfigured = appState.syncServerUrl.isNotEmpty;
    final isActionsEnabled = appState.syncEnabled && isServerAvailable;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _maybeShowIncomingRequestDialog(p2pState);
    });

    return ToolLayout(
      title: FastDropTool.config.localizedName(l10n),
      fullscreen: true,
      showFloatingBackButton: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                const ToolBackButton(),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.fastDropTitle,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        isConfigured
                            ? (appState.syncEnabled
                                  ? (isServerAvailable
                                        ? l10n.fastDropStatusOnline
                                        : l10n.fastDropStatusOffline)
                                  : l10n.fastDropStatusSyncDisabled)
                            : l10n.fastDropStatusNotConfigured,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isConfigured
                              ? (appState.syncEnabled
                                    ? (isServerAvailable
                                          ? AppTheme.statusGreen
                                          : AppTheme.statusRed)
                                    : AppTheme.statusAmber)
                              : theme.colorScheme.onSurface.withValues(
                                  alpha: 0.5,
                                ),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isConfigured && appState.syncEnabled)
                  IconButton(
                    icon: isLoadingFastDrops
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.accentTeal,
                            ),
                          )
                        : const Icon(Icons.refresh),
                    tooltip: l10n.fastDropRefreshList,
                    onPressed: () => fastDropState.loadFastDrops(),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: FastDropModeToggle(
              mode: _mode,
              cloudLabel: l10n.fastDropModeCloud,
              nearbyLabel: l10n.fastDropModeNearby,
              onChanged: (mode) => setState(() => _mode = mode),
            ),
          ),
          const Divider(height: 1),
          const FastDropTransferProgress(),
          if (_mode == FastDropMode.cloud)
            FastDropStatusBanner(
              appState: fastDropState,
              onRetry: () => fastDropState.loadFastDrops(),
            ),
          Expanded(
            child: _mode == FastDropMode.nearby
                ? FastDropP2pView(
                    p2pState: p2pState,
                    onFilesPickedToSend: _onFilePickedToSend,
                    onPasteClipboardToSend: _onPasteClipboardToSend,
                    onSelectPeer: _onSelectPeer,
                    onCancelSendSelection: _onCancelSendSelection,
                    onToggleReceiving: _onToggleReceiving,
                    onOpenReceived: _onOpenReceived,
                    onSaveReceived: _onSaveReceived,
                    onDismissReceived: _onDismissReceived,
                    onCancelTransfer: () => p2pState.cancelTransfer(),
                  )
                : !isConfigured
                ? const FastDropNotConfigured()
                : ResponsiveOrientationLayout(
                    portrait: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_pendingSharedFiles.isNotEmpty) ...[
                              FastDropPendingCard(
                                files: _pendingSharedFiles,
                                isUploading: _isUploadingPending,
                                isActionsEnabled: isActionsEnabled,
                                onUpload: _uploadPendingSharedFiles,
                                onDismiss: () {
                                  setState(() {
                                    _pendingSharedFiles.clear();
                                  });
                                },
                              ),
                              const SizedBox(height: 16),
                            ],
                            FastDropUploadPanel(
                              retention: _retention,
                              onRetentionChanged: _onRetentionChanged,
                              onFilesSelected: _onFilesSelected,
                              onPasteClipboard: _pasteFromClipboard,
                              isActionsEnabled: isActionsEnabled,
                            ),
                            const SizedBox(height: 24),
                            const Divider(height: 1),
                            const SizedBox(height: 16),
                            Text(
                              l10n.fastDropSectionTitle,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.5,
                                ),
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            FastDropList(
                              appState: fastDropState,
                              shrinkWrap: true,
                              onDelete: _onDelete,
                              onPreview: _onPreview,
                              onOpen: _onOpen,
                              onDownload: _onDownload,
                              onEditDescription: _onUpdateDescription,
                              onEditRetention: _onUpdateRetention,
                            ),
                          ],
                        ),
                      ),
                    ),
                    landscape: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 320,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (_pendingSharedFiles.isNotEmpty) ...[
                                  FastDropPendingCard(
                                    files: _pendingSharedFiles,
                                    isUploading: _isUploadingPending,
                                    isActionsEnabled: isActionsEnabled,
                                    onUpload: _uploadPendingSharedFiles,
                                    onDismiss: () {
                                      setState(() {
                                        _pendingSharedFiles.clear();
                                      });
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                ],
                                FastDropUploadPanel(
                                  retention: _retention,
                                  onRetentionChanged: _onRetentionChanged,
                                  onFilesSelected: _onFilesSelected,
                                  onPasteClipboard: _pasteFromClipboard,
                                  isActionsEnabled: isActionsEnabled,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const VerticalDivider(width: 1),
                        Expanded(
                          child: FastDropList(
                            appState: fastDropState,
                            onDelete: _onDelete,
                            onPreview: _onPreview,
                            onOpen: _onOpen,
                            onDownload: _onDownload,
                            onEditDescription: _onUpdateDescription,
                            onEditRetention: _onUpdateRetention,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
