import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/markdown_view.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';
import '../fast_drop_model.dart';

class FastDropPreviewDialog extends StatefulWidget {
  final FastDropItem item;
  final Future<Uint8List> Function(String id) onDownload;
  final VoidCallback onOpen;
  final VoidCallback onSave;

  const FastDropPreviewDialog({
    super.key,
    required this.item,
    required this.onDownload,
    required this.onOpen,
    required this.onSave,
  });

  @override
  State<FastDropPreviewDialog> createState() => _FastDropPreviewDialogState();
}

class _FastDropPreviewDialogState extends State<FastDropPreviewDialog> {
  late Future<Uint8List> _downloadFuture;

  @override
  void initState() {
    super.initState();
    _downloadFuture = widget.onDownload(widget.item.id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isText =
        widget.item.type.startsWith('text/') ||
        widget.item.type.contains('json') ||
        widget.item.type.contains('javascript') ||
        widget.item.type.contains('xml');
    final isMarkdown =
        widget.item.type == 'text/markdown' ||
        widget.item.filename.endsWith('.md');
    final isImage = widget.item.type.startsWith('image/');

    return ResponsiveAlertDialog(
      title: Text(
        widget.item.filename,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      content: SizedBox(
        width: 600,
        height: 400,
        child: FutureBuilder<Uint8List>(
          future: _downloadFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: AppTheme.accentTeal),
                    SizedBox(height: 16),
                    Text('Downloading file for preview...'),
                  ],
                ),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: AppTheme.statusRed,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load preview:\n${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ],
                ),
              );
            }

            final bytes = snapshot.data!;
            if (isImage) {
              return Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(bytes, fit: BoxFit.contain),
                ),
              );
            }

            if (isText) {
              final text = utf8.decode(bytes, allowMalformed: true);
              if (isMarkdown) {
                return SingleChildScrollView(
                  child: MarkdownView(
                    data: text,
                    accentColor: AppTheme.accentTeal,
                  ),
                );
              } else {
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      text,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              }
            }

            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.file_open_outlined,
                    size: 64,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Preview not available for this file type.',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.item.type,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        FilledButton.icon(
          onPressed: () {
            Navigator.of(context).pop();
            widget.onOpen();
          },
          icon: const Icon(Icons.open_in_new),
          label: const Text('Open / Share'),
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.secondaryContainer,
            foregroundColor: theme.colorScheme.onSecondaryContainer,
          ),
        ),
        FilledButton.icon(
          onPressed: () {
            Navigator.of(context).pop();
            widget.onSave();
          },
          icon: const Icon(Icons.download),
          label: const Text('Download'),
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.accentTeal,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
