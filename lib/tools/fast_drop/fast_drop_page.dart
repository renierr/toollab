import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_selector/file_selector.dart' show XFile;
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/core/shared_file.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import 'package:tool_lab/helpers/mime_type_helper.dart';
import 'package:tool_lab/widgets/tool_layout.dart';
import 'package:tool_lab/widgets/file_drop_zone.dart';
import 'package:tool_lab/widgets/confirm_action_dialog.dart';
import 'package:tool_lab/widgets/responsive_orientation_layout.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/providers/app_state.dart';
import 'package:tool_lab/services/database_service.dart';

import 'config.dart';
import 'fast_drop_model.dart';
import 'widgets/fast_drop_item_card.dart';
import 'widgets/fast_drop_preview_dialog.dart';
import 'widgets/retention_selector.dart';

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

  Future<void> _pasteFromClipboard() async {
    final appState = context.read<AppState>();
    if (!appState.syncEnabled || !appState.isServerAvailable) return;
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      final text = clipboardData?.text;
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Uploaded successfully!')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No text content found in clipboard')),
          );
        }
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

  Widget _buildPendingSharedFileCard(ThemeData theme) {
    if (_pendingSharedFile == null) return const SizedBox();
    final appState = context.read<AppState>();
    final isActionsEnabled = appState.syncEnabled && appState.isServerAvailable;

    return Card(
      color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.7),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.secondary, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.share_outlined,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Shared File Received',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    setState(() {
                      _pendingSharedFile = null;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _pendingSharedFile!.name,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSecondaryContainer,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            if (_isUploadingPending)
              const LinearProgressIndicator(color: AppTheme.accentTeal)
            else
              FilledButton.icon(
                onPressed: isActionsEnabled ? _uploadPendingSharedFile : null,
                icon: const Icon(Icons.cloud_upload_outlined),
                label: const Text('Upload to Server'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.accentTeal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBanner(AppState appState, ThemeData theme) {
    if (!appState.syncEnabled) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.statusAmber.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.statusAmber, width: 1),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.warning_amber_outlined,
              color: AppTheme.statusAmber,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cloud Sync is Disabled',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Fast Drop requires cloud sync to be enabled in settings.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => context.push('/sync-settings'),
              child: const Text('Enable'),
            ),
          ],
        ),
      );
    }

    if (!appState.isServerAvailable) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.statusRed.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.statusRed, width: 1),
        ),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_outlined, color: AppTheme.statusRed),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sync Server Unreachable',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Check connection or retry health check to enable operations.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.refresh, color: AppTheme.statusRed),
              tooltip: 'Retry Connection',
              onPressed: () => appState.loadFastDrops(),
            ),
          ],
        ),
      );
    }

    return const SizedBox();
  }

  Widget _buildDropsList(
    AppState appState,
    ThemeData theme, {
    bool shrinkWrap = false,
  }) {
    if (appState.isLoadingFastDrops && appState.fastDrops.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 32.0),
          child: CircularProgressIndicator(color: AppTheme.accentTeal),
        ),
      );
    }

    if (appState.fastDropError != null && appState.fastDrops.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.cloud_off_outlined,
                size: 64,
                color: theme.colorScheme.error.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 16),
              Text(
                'Connection Status',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                appState.fastDropError!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 24),
              if (appState.syncEnabled)
                FilledButton.icon(
                  onPressed: () => appState.loadFastDrops(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry connection'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.accentTeal,
                    foregroundColor: Colors.white,
                  ),
                ),
            ],
          ),
        ),
      );
    }

    if (appState.fastDrops.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.cloud_queue_outlined,
                size: 64,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              Text(
                'No Drops Yet',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Drag and drop files or paste content from clipboard to save temporarily.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final listView = ListView.builder(
      padding: shrinkWrap
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: appState.fastDrops.length,
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      itemBuilder: (context, index) {
        final item = appState.fastDrops[index];
        return FastDropItemCard(
          item: item,
          onDelete: () => _onDelete(item),
          onKeep: () => _onKeep(item),
          onPreview: () => _onPreview(item),
          onOpen: () => _onOpen(item),
          onDownload: () => _onDownload(item),
        );
      },
    );

    if (shrinkWrap) {
      return listView;
    }

    return RefreshIndicator(
      onRefresh: () => appState.loadFastDrops(),
      color: AppTheme.accentTeal,
      child: listView,
    );
  }

  Widget _buildNotConfiguredState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 80,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 24),
            Text(
              'Sync Server Not Configured',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Fast Drop requires a connection to the backend server. Please configure your Sync Server URL in settings to start dropping files.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => context.push('/sync-settings'),
              icon: const Icon(Icons.settings_outlined),
              label: const Text('Configure Server'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.accentTeal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
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
      showFloatingBackButton:
          false, // Hide overlay back button to place our own
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Custom header that acts as native App Bar but behaves responsive
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
          _buildStatusBanner(appState, theme),
          Expanded(
            child: !isConfigured
                ? _buildNotConfiguredState(theme)
                : ResponsiveOrientationLayout(
                    portrait: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_pendingSharedFile != null) ...[
                              _buildPendingSharedFileCard(theme),
                              const SizedBox(height: 16),
                            ],
                            RetentionSelector(
                              selectedValue: _retention,
                              onChanged: (val) {
                                setState(() => _retention = val);
                                DatabaseService.instance.setSetting(
                                  'fast-drop',
                                  'retention',
                                  val,
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            Opacity(
                              opacity: isActionsEnabled ? 1.0 : 0.5,
                              child: AbsorbPointer(
                                absorbing: !isActionsEnabled,
                                child: SizedBox(
                                  height: Platform.isAndroid ? 160 : 290,
                                  child: FileDropZone(
                                    onFileSelected: _onFileSelected,
                                    allowedExtensions: const [],
                                    typeLabel: 'All Files',
                                    accentColor:
                                        FastDropTool.config.accentColor,
                                    icon: Icons.cloud_upload_outlined,
                                    title: Platform.isAndroid
                                        ? 'Select a file to upload'
                                        : 'Drop files here',
                                    subtitle: 'or click to browse',
                                    compact: Platform.isAndroid,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: isActionsEnabled
                                      ? _pasteFromClipboard
                                      : null,
                                  icon: const Icon(Icons.paste_outlined),
                                  label: const Text('Paste Clipboard'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.accentTeal,
                                    side: const BorderSide(
                                      color: AppTheme.accentTeal,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ],
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
                            _buildDropsList(appState, theme, shrinkWrap: true),
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
                                  _buildPendingSharedFileCard(theme),
                                  const SizedBox(height: 16),
                                ],
                                RetentionSelector(
                                  selectedValue: _retention,
                                  onChanged: (val) {
                                    setState(() => _retention = val);
                                    DatabaseService.instance.setSetting(
                                      'fast-drop',
                                      'retention',
                                      val,
                                    );
                                  },
                                ),
                                const SizedBox(height: 16),
                                Opacity(
                                  opacity: isActionsEnabled ? 1.0 : 0.5,
                                  child: AbsorbPointer(
                                    absorbing: !isActionsEnabled,
                                    child: SizedBox(
                                      height: Platform.isAndroid ? 160 : 290,
                                      child: FileDropZone(
                                        onFileSelected: _onFileSelected,
                                        allowedExtensions: const [],
                                        typeLabel: 'All Files',
                                        accentColor:
                                            FastDropTool.config.accentColor,
                                        icon: Icons.cloud_upload_outlined,
                                        title: Platform.isAndroid
                                            ? 'Select a file to upload'
                                            : 'Drop here to upload',
                                        subtitle: 'or click to browse',
                                        compact: Platform.isAndroid,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  alignment: WrapAlignment.center,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: isActionsEnabled
                                          ? _pasteFromClipboard
                                          : null,
                                      icon: const Icon(Icons.paste_outlined),
                                      label: const Text('Paste Clipboard'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppTheme.accentTeal,
                                        side: const BorderSide(
                                          color: AppTheme.accentTeal,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const VerticalDivider(width: 1),
                        Expanded(
                          child: _buildDropsList(
                            appState,
                            theme,
                            shrinkWrap: false,
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
