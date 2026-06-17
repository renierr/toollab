import 'dart:io';
import 'package:flutter/material.dart';
import 'package:tool_lab/core/tool_localization.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/core/shared_file.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/services/sharing_service.dart';
import 'package:tool_lab/widgets/markdown_viewer_page.dart';
import 'package:tool_lab/tools/markdown_viewer/config.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/file_drop_zone.dart';
import 'package:file_selector/file_selector.dart' show XFile;

class MarkdownViewerToolPage extends StatefulWidget {
  final SharedFile? sharedFile;

  const MarkdownViewerToolPage({super.key, this.sharedFile});

  @override
  State<MarkdownViewerToolPage> createState() => _MarkdownViewerToolPageState();
}

class _MarkdownViewerToolPageState extends State<MarkdownViewerToolPage>
    with DisposeCleanup {
  String? _fileContent;
  String? _fileName;

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

  void _onClose() {
    if (widget.sharedFile != null) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        setState(() {
          _fileContent = null;
          _fileName = null;
        });
      }
    } else {
      setState(() {
        _fileContent = null;
        _fileName = null;
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
      return Scaffold(
        appBar: AppBar(
          title: Text(MarkdownViewerTool.config.localizedName(l10n)),
        ),
        body: FileDropZone(
          onFileSelected: _onFileSelected,
          allowedExtensions: MarkdownViewerTool.config.fileExtensions,
          allowedMimeTypes: const ['text/markdown', 'text/plain'],
          typeLabel: l10n.miscMarkdownTypeLabel,
          accentColor: accent,
          title: l10n.miscMarkdownOpenTitle,
          subtitle: l10n.miscMarkdownDropSubtitle,
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
        onClose: _onClose,
        exportSuggestedName: _fileName ?? 'document.md',
      ),
    );
  }
}
