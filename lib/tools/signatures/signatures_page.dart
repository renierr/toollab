import 'dart:convert';
import 'package:tool_lab/helpers/debug_log.dart';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/helpers/clipboard_helper.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import 'package:tool_lab/helpers/temp_file_manager.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';
import 'package:tool_lab/widgets/tool_layout.dart';

import 'package:tool_lab/providers/app_state.dart';
import 'package:tool_lab/theme/theme.dart';
import 'config.dart';
import 'signature_export.dart';
import 'signature_models.dart';
import 'signature_painter.dart';
import 'signatures_state.dart';
import 'signatures_sync_delegate.dart';
import 'widgets/signature_advanced_panel.dart';
import 'widgets/signature_canvas.dart';
import 'widgets/signature_controls.dart';
import 'widgets/signature_gallery.dart';
import 'widgets/signature_toolbar.dart';

class SignaturesPage extends StatefulWidget {
  const SignaturesPage({super.key});

  @override
  State<SignaturesPage> createState() => _SignaturesPageState();
}

class _SignaturesPageState extends State<SignaturesPage>
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = context.read<AppState>();
      if (appState.syncEnabled &&
          appState.syncServerUrl.isNotEmpty &&
          appState.isToolSyncEnabled(SignaturesTool.config.id)) {
        appState
            .syncWithBackend([SignaturesSyncDelegate()])
            .then((_) {
              if (mounted) {
                context.read<SignaturesState>().refreshSaved();
              }
            })
            .catchError((e) {
              errorLog('[SignaturesPage] Auto-sync on open failed: $e');
            });
      }
    });
  }

  String _fileName(String ext) =>
      'signature-${DateTime.now().millisecondsSinceEpoch}.$ext';

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _savePngBytes(List<int> bytes) async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    await FileSaveHelper.saveFile(
      context: context,
      suggestedName: _fileName('png'),
      bytes: Uint8List.fromList(bytes),
      acceptedTypeGroups: [
        XTypeGroup(label: l10n.sigPngImage, extensions: ['png']),
      ],
      successMessageAndroid: l10n.sigSavedToDownloads,
    );
  }

  Future<void> _saveSvgString(String svg) async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    await FileSaveHelper.saveFile(
      context: context,
      suggestedName: _fileName('svg'),
      bytes: Uint8List.fromList(utf8.encode(svg)),
      acceptedTypeGroups: [
        XTypeGroup(label: l10n.sigSvgImage, extensions: ['svg']),
      ],
      successMessageAndroid: l10n.sigSavedToDownloads,
    );
  }

  Future<void> _exportCurrentPng() async {
    final bytes = await context.read<SignaturesState>().exportCurrentPng();
    if (bytes == null) return;
    await _savePngBytes(bytes);
  }

  Future<void> _exportCurrentSvg() async {
    final svg = context.read<SignaturesState>().exportCurrentSvg();
    if (svg == null) return;
    await _saveSvgString(svg);
  }

  Future<void> _copy() async {
    final bytes = await context.read<SignaturesState>().exportCurrentPng();
    if (bytes == null) return;
    final success = await ClipboardHelper.copyImageBytes(bytes);
    if (!mounted) return;
    if (success) {
      _toast(AppLocalizations.of(context).sigCopiedToClipboard);
    } else {
      _toast(AppLocalizations.of(context).sigCopyFailed);
    }
  }

  Future<void> _share() async {
    final bytes = await context.read<SignaturesState>().exportCurrentPng();
    if (bytes == null || !mounted) return;
    final path = await _tempScope.createFile(
      _fileName('png'),
      bytes: Uint8List.fromList(bytes),
    );
    if (!mounted) return;
    await FileSaveHelper.showShareChooser(
      context: context,
      path: path,
      mimeType: 'image/png',
    );
  }

  Future<void> _save() async {
    final ok = await context.read<SignaturesState>().save();
    if (ok && mounted) _toast(AppLocalizations.of(context).sigSaved);
  }

  Future<void> _triggerSync() async {
    final l10n = AppLocalizations.of(context);
    final appState = context.read<AppState>();
    if (appState.syncServerUrl.isEmpty) {
      _toast(l10n.notesSyncConfigureServerUrl);
      return;
    }
    if (!appState.isToolSyncEnabled(SignaturesTool.config.id)) {
      _toast(l10n.coreSyncToolDisabled);
      return;
    }

    try {
      final results = await appState.syncWithBackend([
        SignaturesSyncDelegate(),
      ]);
      if (results != null) {
        if (mounted) {
          context.read<SignaturesState>().refreshSaved();
          _toast(
            l10n.notesSyncFinished(
              results['pulled'] ?? 0,
              results['pushed'] ?? 0,
              results['deleted'] ?? 0,
            ),
          );
        }
      } else {
        if (mounted) {
          _toast(l10n.notesSyncFailedEmpty);
        }
      }
    } catch (e) {
      if (mounted) {
        _toast(l10n.notesSyncFailed(e.toString()));
      }
    }
  }

  void _loadRecord(SignatureRecord record) {
    context.read<SignaturesState>().loadRecord(record);
    _tabController.animateTo(0);
  }

  Future<void> _exportRecordPng(SignatureRecord record) async {
    final bytes = await renderSignaturePng(
      record.rawPaths,
      record.width,
      record.height,
      record.settings,
    );
    await _savePngBytes(bytes);
  }

  Future<void> _exportRecordSvg(SignatureRecord record) async {
    final svg = generateSignatureSvg(
      record.rawPaths,
      record.width,
      record.height,
      record.settings,
    );
    await _saveSvgString(svg);
  }

  Future<void> _deleteRecord(SignatureRecord record) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => ResponsiveAlertDialog(
        title: Text(l10n.sigDeleteTitle),
        content: Text(l10n.sigDeleteContent),
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
    await context.read<SignaturesState>().deleteSaved(record.shortId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final appState = context.watch<AppState>();
    return ToolLayout(
      scaffoldKey: _scaffoldKey,
      title: SignaturesTool.config.localizedName(l10n),
      endDrawer: const SignatureAdvancedPanel(),
      actions: [
        if (appState.syncEnabled && appState.syncServerUrl.isNotEmpty)
          IconButton(
            tooltip: l10n.chipSyncTooltip,
            icon: appState.isSyncing
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppTheme.accentBlue,
                      ),
                    ),
                  )
                : const Icon(Icons.sync),
            onPressed: appState.isSyncing ? null : _triggerSync,
          ),
        IconButton(
          tooltip: l10n.sigAdvancedSettings,
          icon: const Icon(Icons.tune),
          onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
        ),
      ],
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            tabs: [
              Tab(text: l10n.sigTabDraw),
              Tab(text: l10n.sigTabSaved),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _DrawTab(
                  onCopy: _copy,
                  onShare: _share,
                  onExportPng: _exportCurrentPng,
                  onExportSvg: _exportCurrentSvg,
                  onSave: _save,
                ),
                SignatureGallery(
                  onLoad: _loadRecord,
                  onDelete: _deleteRecord,
                  onExportPng: _exportRecordPng,
                  onExportSvg: _exportRecordSvg,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawTab extends StatelessWidget {
  final VoidCallback onCopy;
  final VoidCallback onShare;
  final VoidCallback onExportPng;
  final VoidCallback onExportSvg;
  final VoidCallback onSave;

  const _DrawTab({
    required this.onCopy,
    required this.onShare,
    required this.onExportPng,
    required this.onExportSvg,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Expanded(
          child: Padding(padding: EdgeInsets.all(12), child: SignatureCanvas()),
        ),
        const SignatureControls(),
        SignatureToolbar(
          onCopy: onCopy,
          onShare: onShare,
          onExportPng: onExportPng,
          onExportSvg: onExportSvg,
          onSave: onSave,
        ),
      ],
    );
  }
}
