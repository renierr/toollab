import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import 'package:tool_lab/helpers/format_helper.dart';
import 'package:tool_lab/helpers/pdf_export_helper.dart';
import 'package:tool_lab/helpers/temp_file_manager.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/tools/notes/widgets/note_card_tags.dart';

class NoteCard extends StatelessWidget {
  final Map<String, dynamic> note;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  String _getTitle(String content, {required String untitledFallback}) {
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
    return untitledFallback;
  }

  String _getPreviewContent(String content) {
    final lines = content.split('\n');
    int titleIdx = -1;
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].trim().isNotEmpty) {
        titleIdx = i;
        break;
      }
    }

    if (titleIdx == -1) return '';

    final remainingLines = lines
        .skip(titleIdx + 1)
        .where((l) => l.trim().isNotEmpty)
        .toList();
    if (remainingLines.isEmpty) {
      return content;
    }
    return remainingLines.join('\n');
  }

  String _formatDate(int timestamp) => FormatHelper.epoch(timestamp);

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

  Future<void> _exportPdf(BuildContext context) async {
    final content = note['content'] as String;
    final shortId = note['short_id'] as String;
    await PdfExportHelper.exportMarkdown(
      context: context,
      markdown: content,
      suggestedName: 'note-$shortId.pdf',
      title: _getTitle(
        content,
        untitledFallback: AppLocalizations.of(context).notesUntitledNote,
      ),
    );
  }

  Future<void> _shareNote(BuildContext context) async {
    final content = note['content'] as String;
    final shortId = note['short_id'] as String;

    if (Platform.isAndroid || Platform.isWindows) {
      try {
        final tempPath = await TempFileManager.createFile('note-$shortId.md');
        await File(tempPath).writeAsString(content);
        if (context.mounted) {
          await FileSaveHelper.showShareChooser(
            context: context,
            path: tempPath,
            mimeType: 'text/markdown',
          );
        }
      } catch (e) {
        await SharePlus.instance.share(ShareParams(text: content));
      }
    } else {
      await SharePlus.instance.share(ShareParams(text: content));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final content = note['content'] as String? ?? '';
    final title = _getTitle(content, untitledFallback: l10n.notesUntitledNote);
    final bodyPreview = _getPreviewContent(content);
    final updatedAt = note['updated_at'] as int? ?? 0;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isConstrained = constraints.maxHeight < double.infinity;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: isConstrained
                    ? MainAxisSize.max
                    : MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.accentTeal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, size: 20),
                        onSelected: (value) {
                          if (value == 'edit') {
                            onEdit();
                          } else if (value == 'delete') {
                            onDelete();
                          } else if (value == 'export') {
                            _exportMarkdown(context);
                          } else if (value == 'export_pdf') {
                            _exportPdf(context);
                          } else if (value == 'share') {
                            _shareNote(context);
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                const Icon(Icons.edit_outlined, size: 18),
                                const SizedBox(width: 8),
                                Text(l10n.commonEdit),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'share',
                            child: Row(
                              children: [
                                const Icon(Icons.share_outlined, size: 18),
                                const SizedBox(width: 8),
                                Text(l10n.commonShare),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'export',
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.file_download_outlined,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(l10n.notesExportMd),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'export_pdf',
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.picture_as_pdf_outlined,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(l10n.notesExportPdf),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                  color: theme.colorScheme.error,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  l10n.commonDelete,
                                  style: TextStyle(
                                    color: theme.colorScheme.error,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (bodyPreview.isNotEmpty)
                    Text(
                      bodyPreview,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  const SizedBox(height: 8),
                  NoteCardTags(
                    tags:
                        (note['tags'] as List<dynamic>?)?.cast<String>() ?? [],
                  ),
                  if (isConstrained) const Spacer(),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          l10n.notesUpdatedAt(_formatDate(updatedAt)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.4,
                            ),
                          ),
                        ),
                      ),
                      if ((note['synced'] as int? ?? 0) == 1)
                        Icon(
                          Icons.cloud_done_outlined,
                          size: 14,
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.5,
                          ),
                        )
                      else
                        Icon(
                          Icons.cloud_upload_outlined,
                          size: 14,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.3,
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
