import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_selector/file_selector.dart' show XFile;
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/core/shared_file.dart';
import 'package:tool_lab/helpers/clipboard_helper.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import 'package:tool_lab/helpers/mime_type_helper.dart';
import 'package:tool_lab/widgets/tool_layout.dart';
import 'package:tool_lab/widgets/confirm_action_dialog.dart';
import 'package:tool_lab/widgets/responsive_orientation_layout.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/providers/app_state.dart';
import 'package:tool_lab/services/database_service.dart';

import 'fast_drop_model.dart';
import 'widgets/fast_drop_preview_dialog.dart';
import 'widgets/fast_drop_upload_panel.dart';
import 'widgets/fast_drop_status_banner.dart';
import 'widgets/fast_drop_pending_card.dart';
import 'widgets/fast_drop_list.dart';
import 'widgets/fast_drop_not_configured.dart';

class FastDropPage extends StatefulWidget {
  final SharedFile? sharedFile;

  const FastDropPage({super.key, this.sharedFile});

  @override
  State<FastDropPage> createState() => _FastDropPageState();
}

class _FastDropPageState extends State<FastDropPage> with DisposeCleanup {
  String _retention = '24';
  SharedFile? _pendingSharedFile;
  bool _isUploadingPending = false;

  @override
  void initState() {
    super.initState();

    _pendingSharedFile = widget.sharedFile;

    DatabaseService.instance.getSetting('fast-drop', 'retention').then((val) {
      if (val != null && mounted) {
        setState(() {
          _retention = val;
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AppState>().loadFastDrops();
      }
    });
  }

  @override
  void didUpdateWidget(covariant FastDropPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sharedFile != oldWidget.sharedFile &&
        widget.sharedFile != null) {
      setState(() {
        _pendingSharedFile = widget.sharedFile;
      });
    }
  }

  void _onRetentionChanged(String val) {
    setState(() => _retention = val);
    DatabaseService.instance.setSetting('fast-drop', 'retention', val);
  }

  Future<void> _pasteFromClipboard() async {
    final appState = context.read<AppState>();
    if (!appState.syncEnabled || !appState.isServerAvailable) return;
    try {
      final text = await ClipboardHelper.getText();
      if (text != null && text.trim().isNotEmpty) {
        final bytes = utf8.encode(text);
        final filename =
            'pasted-text-${DateTime.now().millisecondsSinceEpoch}.txt';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pasting text from clipboard...')),
          );
        }
        await appState.uploadFastDrop(
          filename: filename,
          bytes: bytes,
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
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Pasting image from clipboard...')),
            );
          }
          await appState.uploadFastDrop(
            filename: filename,
            bytes: imageBytes,
            retention: _retention,
            source: 'clipboard',
            mimeType: 'image/png',
          );
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No text or image content found in clipboard'),
              ),
            );
          }
          return;
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Uploaded successfully!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to read clipboard: $e')));
      }
    }
  }

  Future<void> _onFileSelected(XFile file) async {
    final appState = context.read<AppState>();
    if (!appState.syncEnabled || !appState.isServerAvailable) return;
    try {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Uploading ${file.name}...')));
      }
      final bytes = await file.readAsBytes();
      String mimeType = file.mimeType ?? 'application/octet-stream';
      if (mimeType == 'application/octet-stream' || mimeType.isEmpty) {
        mimeType = MimeTypeHelper.getMimeType(file.name);
      }
      await appState.uploadFastDrop(
        filename: file.name,
        bytes: bytes,
        retention: _retention,
        source: 'file',
        mimeType: mimeType,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Uploaded successfully!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    }
  }

  Future<void> _uploadPendingSharedFile() async {
    if (_pendingSharedFile == null) return;
    final appState = context.read<AppState>();
    if (!appState.syncEnabled || !appState.isServerAvailable) return;
    final file = _pendingSharedFile!;
    try {
      setState(() {
        _isUploadingPending = true;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Uploading ${file.name}...')));
      }
      final bytes = await File(file.path).readAsBytes();
      String mimeType = file.mimeType;
      if (mimeType == 'application/octet-stream' || mimeType.isEmpty) {
        mimeType = MimeTypeHelper.getMimeType(file.name);
      }
      await appState.uploadFastDrop(
        filename: file.name,
        bytes: bytes,
        retention: _retention,
        source: 'file',
        mimeType: mimeType,
      );
      setState(() {
        _pendingSharedFile = null;
        _isUploadingPending = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Shared file uploaded successfully!')),
        );
      }
    } catch (e) {
      setState(() {
        _isUploadingPending = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload shared file: $e')),
        );
      }
    }
  }

  Future<void> _onKeep(FastDropItem item) async {
    final appState = context.read<AppState>();
    try {
      await appState.keepFastDrop(item.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Retention set to indefinite')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update retention: $e')),
        );
      }
    }
  }

  Future<void> _onDelete(FastDropItem item) async {
    final appState = context.read<AppState>();
    final confirm = await ConfirmActionDialog.show(
      context: context,
      title: 'Delete Drop',
      message: 'Are you sure you want to delete "${item.filename}"?',
      confirmLabel: 'Delete',
    );
    if (confirm == true) {
      try {
        await appState.deleteFastDrop(item.id);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Deleted successfully')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to delete drop: $e')));
        }
      }
    }
  }

  Future<void> _onDownload(FastDropItem item) async {
    final appState = context.read<AppState>();
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Downloading ${item.filename}...')),
        );
      }
      final bytes = await appState.downloadFastDrop(item.id);
      if (!mounted) return;
      await FileSaveHelper.saveFile(
        context: context,
        suggestedName: item.filename,
        bytes: bytes,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Download failed: $e')));
      }
    }
  }

  Future<void> _onOpen(FastDropItem item) async {
    final appState = context.read<AppState>();
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Downloading ${item.filename} to open...')),
        );
      }
      final bytes = await appState.downloadFastDrop(item.id);
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/${item.filename}');
      await tempFile.writeAsBytes(bytes);

      if (mounted) {
        await FileSaveHelper.showOpenChooser(
          context: context,
          path: tempFile.path,
          mimeType: item.type,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to open file: $e')));
      }
    }
  }

  void _onPreview(FastDropItem item) {
    showDialog(
      context: context,
      builder: (context) => FastDropPreviewDialog(
        item: item,
        onDownload: (id) => context.read<AppState>().downloadFastDrop(id),
        onOpen: () => _onOpen(item),
        onSave: () => _onDownload(item),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final theme = Theme.of(context);
    final isConfigured = appState.syncServerUrl.isNotEmpty;
    final isActionsEnabled = appState.syncEnabled && appState.isServerAvailable;

    return ToolLayout(
      title: 'Fast Drop',
      fullscreen: true,
      showFloatingBackButton: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Back',
                  onPressed: () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    } else {
                      context.go('/');
                    }
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Fast Drop',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        isConfigured
                            ? (appState.syncEnabled
                                  ? (appState.isServerAvailable
                                        ? 'Online'
                                        : 'Offline')
                                  : 'Sync Disabled')
                            : 'Not Configured',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isConfigured
                              ? (appState.syncEnabled
                                    ? (appState.isServerAvailable
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
                    icon: appState.isLoadingFastDrops
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.accentTeal,
                            ),
                          )
                        : const Icon(Icons.refresh),
                    tooltip: 'Refresh List',
                    onPressed: () => appState.loadFastDrops(),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (appState.isUploadingFastDrop)
            const LinearProgressIndicator(
              color: AppTheme.accentTeal,
              minHeight: 3,
            ),
          FastDropStatusBanner(
            appState: appState,
            onRetry: () => appState.loadFastDrops(),
          ),
          Expanded(
            child: !isConfigured
                ? const FastDropNotConfigured()
                : ResponsiveOrientationLayout(
                    portrait: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_pendingSharedFile != null) ...[
                              FastDropPendingCard(
                                file: _pendingSharedFile!,
                                isUploading: _isUploadingPending,
                                isActionsEnabled: isActionsEnabled,
                                onUpload: _uploadPendingSharedFile,
                                onDismiss: () {
                                  setState(() {
                                    _pendingSharedFile = null;
                                  });
                                },
                              ),
                              const SizedBox(height: 16),
                            ],
                            FastDropUploadPanel(
                              retention: _retention,
                              onRetentionChanged: _onRetentionChanged,
                              onFileSelected: _onFileSelected,
                              onPasteClipboard: _pasteFromClipboard,
                              isActionsEnabled: isActionsEnabled,
                            ),
                            const SizedBox(height: 24),
                            const Divider(height: 1),
                            const SizedBox(height: 16),
                            Text(
                              'DROPPED FILES',
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
                              appState: appState,
                              shrinkWrap: true,
                              onDelete: _onDelete,
                              onKeep: _onKeep,
                              onPreview: _onPreview,
                              onOpen: _onOpen,
                              onDownload: _onDownload,
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
                                if (_pendingSharedFile != null) ...[
                                  FastDropPendingCard(
                                    file: _pendingSharedFile!,
                                    isUploading: _isUploadingPending,
                                    isActionsEnabled: isActionsEnabled,
                                    onUpload: _uploadPendingSharedFile,
                                    onDismiss: () {
                                      setState(() {
                                        _pendingSharedFile = null;
                                      });
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                ],
                                FastDropUploadPanel(
                                  retention: _retention,
                                  onRetentionChanged: _onRetentionChanged,
                                  onFileSelected: _onFileSelected,
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
                            appState: appState,
                            onDelete: _onDelete,
                            onKeep: _onKeep,
                            onPreview: _onPreview,
                            onOpen: _onOpen,
                            onDownload: _onDownload,
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
