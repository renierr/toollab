import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:url_launcher/url_launcher.dart';

class NoteViewer extends StatelessWidget {
  final Map<String, dynamic> note;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onClose;

  const NoteViewer({
    super.key,
    required this.note,
    required this.onEdit,
    required this.onDelete,
    required this.onClose,
  });

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
    return 'Untitled Note';
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
    final content = note['content'] as String;
    final shortId = note['short_id'] as String;
    final bytes = Uint8List.fromList(utf8.encode(content));
    await FileSaveHelper.saveFile(
      context: context,
      suggestedName: 'note-$shortId.md',
      bytes: bytes,
    );
  }

  Future<void> _shareNote() async {
    final content = note['content'] as String;
    final shortId = note['short_id'] as String;

    if (Platform.isAndroid || Platform.isWindows) {
      try {
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/note-$shortId.md');
        await tempFile.writeAsString(content);
        await FileSaveHelper.shareFile(tempFile.path, 'text/markdown');
      } catch (e) {
        await SharePlus.instance.share(ShareParams(text: content));
      }
    } else {
      await SharePlus.instance.share(ShareParams(text: content));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = note['content'] as String? ?? '';
    final title = _getTitle(content);
    final body = _getPureContent(content);
    final updatedAt = note['updated_at'] as int? ?? 0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onClose();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('View Note'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: onClose,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Share Note',
              onPressed: _shareNote,
            ),
            IconButton(
              icon: const Icon(Icons.file_download_outlined),
              tooltip: 'Export Markdown',
              onPressed: () => _exportMarkdown(context),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit Note',
              onPressed: onEdit,
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
              tooltip: 'Delete Note',
              onPressed: onDelete,
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.accentTeal,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Updated: ${_formatDate(updatedAt)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
                const Divider(height: 32),
                if (body.isEmpty)
                  Text(
                    'No additional content',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  )
                else
                  MarkdownBody(
                    data: body,
                    selectable: true,
                    onTapLink: (text, href, title) {
                      if (href != null) {
                        launchUrl(Uri.parse(href));
                      }
                    },
                    styleSheet: MarkdownStyleSheet.fromTheme(
                      theme,
                    ).copyWith(textScaler: TextScaler.linear(1.0)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
