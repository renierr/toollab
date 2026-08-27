import 'dart:io';
import 'package:flutter/material.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/core/shared_file.dart';
import 'package:tool_lab/core/app_route_observer.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/services/sharing_service.dart';
import 'package:tool_lab/widgets/markdown_viewer_page.dart';
import 'package:tool_lab/tools/markdown_viewer/config.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/tool_layout.dart';
import 'package:file_selector/file_selector.dart' show XFile;

import 'widgets/markdown_open_view.dart';

class MarkdownViewerToolPage extends StatefulWidget {
  final SharedFile? sharedFile;

  const MarkdownViewerToolPage({super.key, this.sharedFile});

  @override
  State<MarkdownViewerToolPage> createState() => _MarkdownViewerToolPageState();
}

class _MarkdownViewerToolPageState extends State<MarkdownViewerToolPage>
    with DisposeCleanup, RouteAware {
  String? _fileContent;
  String? _fileName;
  String? _filePath;
  SharedFile? _sharedFile;

  @override
  void initState() {
    super.initState();

    if (widget.sharedFile != null) {
      _loadSharedFile(widget.sharedFile!);
    }

    final sharingSub = SharingService.instance.onSharedFile.listen((file) {
      final mime = file.mimeType.toLowerCase();
      if (mime == 'text/markdown' ||
          mime == 'text/plain' ||
          file.name.endsWith('.md') ||
          file.name.endsWith('.txt') ||
          file.name.endsWith('.markdown')) {
        _loadSharedFile(file);
      }
    });
    onDispose(sharingSub.cancel);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final route = ModalRoute.of(context);
      if (route != null && mounted) {
        appRouteObserver.subscribe(this, route);
      }
    });
    onDispose(() => appRouteObserver.unsubscribe(this));
  }

  /// A tool pushed above the viewer (e.g. the text editor) may have changed
  /// the file; reload silently when its route pops back.
  @override
  void didPopNext() {
    super.didPopNext();
    _reloadFromDisk(showFeedback: false);
  }

  Future<void> _loadSharedFile(SharedFile file) async {
    try {
      final diskFile = File(file.path);
      if (await diskFile.exists()) {
        final text = await diskFile.readAsString();
        if (mounted) {
          setState(() {
            _fileContent = text;
            _fileName = file.name;
            _filePath = file.path;
            _sharedFile = file;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.miscMarkdownFailedToLoad(e.toString()))),
        );
      }
    }
  }

  Future<void> _onFileSelected(XFile file) async {
    try {
      final content = await file.readAsString();
      if (mounted) {
        setState(() {
          _fileContent = content;
          _fileName = file.name;
          _filePath = file.path.isEmpty ? null : file.path;
          _sharedFile = null;
        });
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.miscMarkdownFailedToRead(e.toString()))),
        );
      }
    }
  }

  Future<void> _reloadFromDisk({bool showFeedback = true}) async {
    final path = _filePath;
    if (path == null) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final diskFile = File(path);
      if (!await diskFile.exists()) {
        if (showFeedback) {
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.miscMarkdownReloadMissing)),
          );
        }
        return;
      }
      final text = await diskFile.readAsString();
      if (!mounted) return;
      final changed = text != _fileContent;
      setState(() => _fileContent = text);
      if (!showFeedback) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            changed
                ? l10n.miscMarkdownReloaded
                : l10n.miscMarkdownReloadNoChange,
          ),
        ),
      );
    } catch (e) {
      if (!showFeedback || !mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.miscMarkdownFailedToRead(e.toString()))),
      );
    }
  }

  void _onClose() {
    if (widget.sharedFile != null) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        setState(() {
          _fileContent = null;
          _fileName = null;
          _filePath = null;
          _sharedFile = null;
        });
      }
    } else {
      setState(() {
        _fileContent = null;
        _fileName = null;
        _filePath = null;
        _sharedFile = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final accent = isLight
        ? AppTheme.accentAmberLight
        : MarkdownViewerTool.config.accentColor;
    final l10n = AppLocalizations.of(context);

    if (_fileContent == null) {
      return ToolLayout(
        title: MarkdownViewerTool.config.localizedName(l10n),
        child: MarkdownOpenView(
          accentColor: accent,
          onFileSelected: _onFileSelected,
        ),
      );
    }

    return MarkdownViewerPage(
      content: _fileContent!,
      config: MarkdownViewerConfig(
        accentColor: accent,
        title: MarkdownViewerTool.config.localizedName(l10n),
        showShare: true,
        showExport: true,
        showEdit: false,
        showDelete: false,
        showReload: _filePath != null,
        onReload: _filePath != null ? _reloadFromDisk : null,
        onClose: _onClose,
        exportSuggestedName: _fileName ?? 'document.md',
        sharedFile: _sharedFile,
      ),
    );
  }
}
