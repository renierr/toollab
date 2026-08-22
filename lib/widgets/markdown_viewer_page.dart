import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tool_lab/core/shared_file.dart';
import 'package:tool_lab/helpers/temp_file_manager.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import 'package:tool_lab/helpers/format_helper.dart';
import 'package:tool_lab/helpers/frontmatter_helper.dart';
import 'package:tool_lab/helpers/pdf_export_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/frontmatter_card.dart';
import 'package:tool_lab/widgets/markdown_loading_skeleton.dart';
import 'package:tool_lab/widgets/markdown_view.dart';
import 'package:tool_lab/widgets/zoomable_area.dart';

class MarkdownViewerConfig {
  final Color accentColor;
  final String title;
  final bool showShare;
  final bool showExport;
  final bool showExportPdf;
  final bool showEdit;
  final bool showDelete;
  final bool showReload;
  final Future<void> Function()? onReload;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onClose;
  final String? exportSuggestedName;
  final String exportMimeType;
  final bool selectable;
  final int? updatedAt;

  /// Original shared file backing the content, when one exists. Forwarded on
  /// share so receiving tools keep the source path and origin metadata
  /// instead of a detached content copy.
  final SharedFile? sharedFile;

  /// Renders a metadata card for YAML frontmatter when the document has one.
  final bool showFrontmatter;

  const MarkdownViewerConfig({
    this.accentColor = AppTheme.accentBlue,
    this.title = 'Markdown Viewer',
    this.showShare = true,
    this.showExport = true,
    this.showExportPdf = true,
    this.showEdit = false,
    this.showDelete = false,
    this.showReload = false,
    this.onReload,
    this.onEdit,
    this.onDelete,
    this.onClose,
    this.exportSuggestedName,
    this.exportMimeType = 'text/markdown',
    this.selectable = true,
    this.updatedAt,
    this.sharedFile,
    this.showFrontmatter = true,
  });
}

class MarkdownViewerPage extends StatefulWidget {
  final String content;
  final MarkdownViewerConfig config;

  const MarkdownViewerPage({
    super.key,
    required this.content,
    this.config = const MarkdownViewerConfig(),
  });

  @override
  State<MarkdownViewerPage> createState() => _MarkdownViewerPageState();
}

class _MarkdownViewerPageState extends State<MarkdownViewerPage> {
  bool _showBody = false;
  bool _reloading = false;
  late FrontmatterResult _frontmatter;

  @override
  void initState() {
    super.initState();
    _frontmatter = FrontmatterHelper.parse(widget.content);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _showBody = true);
    });
  }

  @override
  void didUpdateWidget(MarkdownViewerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.content != oldWidget.content) {
      _frontmatter = FrontmatterHelper.parse(widget.content);
    }
  }

  /// Title from the frontmatter `title` key, else derived from the markdown.
  String? get _frontmatterTitle {
    final raw = _frontmatter.fields['title'];
    if (raw == null || raw is Map || raw is List) return null;
    final title = FrontmatterHelper.formatValue(raw).trim();
    return title.isEmpty ? null : title;
  }

  String _getTitle(String content) {
    final lines = content.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('# ')) {
        return trimmed.substring(2).trim();
      } else if (trimmed.isNotEmpty) {
        if (trimmed.startsWith('## ') || trimmed.startsWith('### ')) {
          return trimmed.replaceAll(RegExp(r'^#+\s+'), '').trim();
        }
        return trimmed;
      }
    }
    return 'Untitled';
  }

  String _getPureContent(String content) {
    final lines = content.split('\n');
    int titleIdx = -1;
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].trim().isNotEmpty) {
        titleIdx = i;
        break;
      }
    }
    if (titleIdx == -1) return '';
    final remainingLines = lines.skip(titleIdx + 1).toList();
    return remainingLines.join('\n').trim();
  }

  String get _resolvedTitle =>
      _frontmatterTitle ?? _getTitle(_frontmatter.body);

  /// Markdown shown below the header. When the title comes from the
  /// frontmatter, the body is only stripped if its first heading repeats it.
  String get _resolvedBody {
    final markdown = _frontmatter.body;
    final fmTitle = _frontmatterTitle;
    if (fmTitle == null) return _getPureContent(markdown);
    return _getTitle(markdown) == fmTitle
        ? _getPureContent(markdown)
        : markdown.trim();
  }

  String _formatDate(int timestamp) => FormatHelper.epoch(timestamp);

  Future<void> _exportMarkdown(BuildContext context) async {
    final bytes = Uint8List.fromList(utf8.encode(widget.content));
    await FileSaveHelper.saveFile(
      context: context,
      suggestedName: widget.config.exportSuggestedName ?? 'document.md',
      bytes: bytes,
    );
  }

  Future<void> _shareContent() async {
    final shared = widget.config.sharedFile;
    if (shared != null && await File(shared.path).exists()) {
      if (!mounted) return;
      await FileSaveHelper.showShareChooser(
        context: context,
        path: shared.path,
        mimeType: shared.mimeType,
        sharedFile: shared,
      );
      return;
    }
    if (Platform.isAndroid || Platform.isWindows) {
      try {
        final tempPath = await TempFileManager.createFile(
          widget.config.exportSuggestedName ?? 'document.md',
        );
        await File(tempPath).writeAsString(widget.content);
        if (mounted) {
          await FileSaveHelper.showShareChooser(
            context: context,
            path: tempPath,
            mimeType: widget.config.exportMimeType,
          );
        }
      } catch (e) {
        await SharePlus.instance.share(ShareParams(text: widget.content));
      }
    } else {
      await SharePlus.instance.share(ShareParams(text: widget.content));
    }
  }

  Future<void> _reload() async {
    final reload = widget.config.onReload;
    if (reload == null || _reloading) return;
    setState(() => _reloading = true);
    try {
      await reload();
    } finally {
      if (mounted) setState(() => _reloading = false);
    }
  }

  Future<void> _exportPdf(BuildContext context) async {
    final fileName =
        '${(widget.config.exportSuggestedName ?? 'document').replaceAll(RegExp(r'\.md$'), '')}.pdf';
    await PdfExportHelper.exportMarkdown(
      context: context,
      markdown: _frontmatter.body,
      suggestedName: fileName,
      title: _resolvedTitle,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final title = _resolvedTitle;
    final body = _resolvedBody;
    final updatedAt = widget.config.updatedAt ?? 0;
    final config = widget.config;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) config.onClose?.call();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(config.title),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: config.onClose,
          ),
          actions: [
            if (config.showReload && config.onReload != null)
              IconButton(
                icon: _reloading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: config.accentColor,
                        ),
                      )
                    : const Icon(Icons.refresh),
                tooltip: l10n.widgetMarkdownReload,
                onPressed: _reloading ? null : _reload,
              ),
            if (config.showShare)
              IconButton(
                icon: const Icon(Icons.share_outlined),
                tooltip: l10n.commonShare,
                onPressed: _shareContent,
              ),
            if (config.showExport)
              IconButton(
                icon: const Icon(Icons.file_download_outlined),
                tooltip: l10n.widgetMarkdownExportMarkdown,
                onPressed: () => _exportMarkdown(context),
              ),
            if (config.showExportPdf)
              IconButton(
                icon: const Icon(Icons.picture_as_pdf_outlined),
                tooltip: l10n.widgetMarkdownExportPdf,
                onPressed: () => _exportPdf(context),
              ),
            if (config.showEdit && config.onEdit != null)
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: l10n.commonEdit,
                onPressed: config.onEdit,
              ),
            if (config.showDelete && config.onDelete != null)
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  color: theme.colorScheme.error,
                ),
                tooltip: l10n.commonDelete,
                onPressed: config.onDelete,
              ),
          ],
        ),
        body: ZoomableArea(
          accentColor: config.accentColor,
          builder: (context, scale, physics) => SafeArea(
            child: SingleChildScrollView(
              physics: physics,
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: config.accentColor,
                    ),
                  ),
                  if (updatedAt > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      l10n.widgetMarkdownUpdated(_formatDate(updatedAt)),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.4,
                        ),
                      ),
                    ),
                  ],
                  const Divider(height: 32),
                  if (config.showFrontmatter &&
                      (_frontmatter.isValid || _frontmatter.error != null))
                    FrontmatterCard(
                      frontmatter: _frontmatter,
                      accentColor: config.accentColor,
                    ),
                  if (body.isEmpty)
                    Text(
                      l10n.widgetMarkdownNoContent,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.4,
                        ),
                      ),
                    )
                  else if (!_showBody)
                    MarkdownLoadingSkeleton(accentColor: config.accentColor)
                  else
                    MarkdownView(
                      data: body,
                      selectable: config.selectable,
                      accentColor: config.accentColor,
                      scale: scale,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
