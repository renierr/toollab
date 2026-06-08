import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tool_lab/helpers/temp_file_manager.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import 'package:tool_lab/helpers/pdf_export_helper.dart';
import 'package:tool_lab/theme/theme.dart';
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
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onClose;
  final String? exportSuggestedName;
  final String exportMimeType;
  final bool selectable;
  final int? updatedAt;

  const MarkdownViewerConfig({
    this.accentColor = AppTheme.accentBlue,
    this.title = 'Markdown Viewer',
    this.showShare = true,
    this.showExport = true,
    this.showExportPdf = true,
    this.showEdit = false,
    this.showDelete = false,
    this.onEdit,
    this.onDelete,
    this.onClose,
    this.exportSuggestedName,
    this.exportMimeType = 'text/markdown',
    this.selectable = true,
    this.updatedAt,
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _showBody = true);
    });
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

  String _formatDate(int timestamp) {
    if (timestamp == 0) return '';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '${date.year}-$month-$day $hour:$minute';
  }

  Future<void> _exportMarkdown(BuildContext context) async {
    final bytes = Uint8List.fromList(utf8.encode(widget.content));
    await FileSaveHelper.saveFile(
      context: context,
      suggestedName: widget.config.exportSuggestedName ?? 'document.md',
      bytes: bytes,
    );
  }

  Future<void> _shareContent() async {
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

  Future<void> _exportPdf(BuildContext context) async {
    final fileName =
        '${(widget.config.exportSuggestedName ?? 'document').replaceAll(RegExp(r'\.md$'), '')}.pdf';
    await PdfExportHelper.exportMarkdown(
      context: context,
      markdown: widget.content,
      suggestedName: fileName,
      title: _getTitle(widget.content),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = widget.content;
    final title = _getTitle(content);
    final body = _getPureContent(content);
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
            if (config.showShare)
              IconButton(
                icon: const Icon(Icons.share_outlined),
                tooltip: 'Share',
                onPressed: _shareContent,
              ),
            if (config.showExport)
              IconButton(
                icon: const Icon(Icons.file_download_outlined),
                tooltip: 'Export Markdown',
                onPressed: () => _exportMarkdown(context),
              ),
            if (config.showExportPdf)
              IconButton(
                icon: const Icon(Icons.picture_as_pdf_outlined),
                tooltip: 'Export PDF',
                onPressed: () => _exportPdf(context),
              ),
            if (config.showEdit && config.onEdit != null)
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit',
                onPressed: config.onEdit,
              ),
            if (config.showDelete && config.onDelete != null)
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  color: theme.colorScheme.error,
                ),
                tooltip: 'Delete',
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
                      'Updated: ${_formatDate(updatedAt)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.4,
                        ),
                      ),
                    ),
                  ],
                  const Divider(height: 32),
                  if (body.isEmpty)
                    Text(
                      'No additional content',
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
