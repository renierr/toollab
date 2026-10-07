import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/shared_file.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import 'package:tool_lab/helpers/temp_file_manager.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/services/sharing_service.dart';
import 'package:tool_lab/widgets/tool_layout.dart';
import 'package:url_launcher/url_launcher.dart';

import 'config.dart';
import 'models/paperless_document.dart';
import 'paperless_error_text.dart';
import 'paperless_state.dart';
import 'widgets/paperless_document_sheet.dart';
import 'widgets/paperless_documents_view.dart';
import 'widgets/paperless_not_configured.dart';
import 'widgets/paperless_settings_page.dart';
import 'widgets/paperless_stats_view.dart';
import 'widgets/paperless_tab_bar.dart';
import 'widgets/paperless_upload_view.dart';

class PaperlessPage extends StatefulWidget {
  final SharedData? sharedData;

  const PaperlessPage({super.key, this.sharedData});

  @override
  State<PaperlessPage> createState() => _PaperlessPageState();
}

class _PaperlessPageState extends State<PaperlessPage>
    with DisposeCleanup, SingleTickerProviderStateMixin {
  static const _uploadTab = 1;

  late final TempFileScope _scope;
  late final TabController _tabs;
  double? _downloadProgress;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _scope = TempFileManager.createScope();
    onDispose(() => _scope.cleanTracked());

    final hasFiles = widget.sharedData?.files.isNotEmpty ?? false;
    _tabs = TabController(
      length: 3,
      vsync: this,
      initialIndex: hasFiles ? _uploadTab : 0,
    );
    onDispose(_tabs.dispose);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _queueFiles(widget.sharedData?.files ?? const []);
      context.read<PaperlessState>().refreshAll();
    });

    final sharingSub = SharingService.instance.onSharedData.listen(
      (data) => _queueFiles(data.files),
    );
    onDispose(sharingSub.cancel);
  }

  void _queueFiles(List<SharedFile> files) {
    // The sharing stream also carries shares routed to other tools.
    final accepted = files.where(
      (file) => SharingService.instance
          .getMatchingTools(file)
          .any((tool) => tool.id == PaperlessTool.config.id),
    );
    if (accepted.isEmpty) return;
    context.read<PaperlessState>().addUploadFiles([
      for (final file in accepted) (path: file.path, name: file.name),
    ]);
    _tabs.animateTo(_uploadTab);
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const PaperlessSettingsPage()),
    );
  }

  void _showDocument(PaperlessDocument document) {
    PaperlessDocumentSheet.show(
      context,
      document: document,
      onOpen: () => _download(document, share: false),
      onShare: () => _download(document, share: true),
      onOpenInBrowser: () => _openInBrowser(document),
    );
  }

  Future<void> _download(
    PaperlessDocument document, {
    required bool share,
  }) async {
    final api = context.read<PaperlessState>().api;
    if (api == null || _isDownloading) return;
    final l10n = AppLocalizations.of(context);
    setState(() {
      _isDownloading = true;
      _downloadProgress = null;
    });
    try {
      final file = await api.download(
        document,
        createTarget: (fileName) async =>
            File(await _scope.createFile('paperless_${document.id}/$fileName')),
        onProgress: (received, total) {
          if (!mounted || total <= 0) return;
          setState(() => _downloadProgress = received / total);
        },
      );
      if (!mounted) return;
      if (share) {
        await FileSaveHelper.showShareChooser(
          context: context,
          path: file.path,
          mimeType: file.mimeType,
        );
      } else {
        await FileSaveHelper.showOpenChooser(
          context: context,
          path: file.path,
          mimeType: file.mimeType,
        );
      }
    } catch (e) {
      errorLog('[PaperlessPage] Download of ${document.id} failed: $e');
      if (mounted) {
        FileSaveHelper.showErrorNotification(
          context: context,
          errorMessage: l10n.paperlessDownloadFailed(
            describePaperlessError(l10n, e),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _openInBrowser(PaperlessDocument document) async {
    final api = context.read<PaperlessState>().api;
    if (api == null) return;
    final opened = await launchUrl(
      api.documentWebUri(document.id),
      mode: LaunchMode.externalApplication,
    );
    if (!opened) errorLog('[PaperlessPage] Could not open browser');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<PaperlessState>();
    final configured = state.isConfigured;

    return ToolLayout(
      title: PaperlessTool.config.localizedName(l10n),
      actions: [
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          tooltip: l10n.commonSettings,
          onPressed: _openSettings,
        ),
      ],
      child: Column(
        children: [
          PaperlessTabBar(
            controller: _tabs,
            pendingUploads: state.pendingUploadCount,
          ),
          if (_isDownloading) LinearProgressIndicator(value: _downloadProgress),
          Expanded(
            child: !state.isLoaded
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabs,
                    children: [
                      configured
                          ? PaperlessDocumentsView(onSelect: _showDocument)
                          : PaperlessNotConfigured(
                              onOpenSettings: _openSettings,
                            ),
                      PaperlessUploadView(
                        scope: _scope,
                        onOpenSettings: _openSettings,
                      ),
                      configured
                          ? const PaperlessStatsView()
                          : PaperlessNotConfigured(
                              onOpenSettings: _openSettings,
                            ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
