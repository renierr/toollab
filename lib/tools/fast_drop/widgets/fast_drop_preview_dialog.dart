import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/markdown_view.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';
import 'package:tool_lab/helpers/mime_type_helper.dart';
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
  Future<Uint8List>? _downloadFuture;

  bool get _isPreviewable {
    final resolvedMimeType = widget.item.type == 'application/octet-stream'
        ? MimeTypeHelper.getMimeType(widget.item.filename)
        : widget.item.type;

    return resolvedMimeType.startsWith('text/') ||
        resolvedMimeType.startsWith('image/') ||
        resolvedMimeType.contains('json') ||
        resolvedMimeType.contains('javascript') ||
        resolvedMimeType.contains('xml');
  }

  @override
  void initState() {
    super.initState();
    if (_isPreviewable) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _downloadFuture = widget.onDownload(widget.item.id);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolvedMimeType = widget.item.type == 'application/octet-stream'
        ? MimeTypeHelper.getMimeType(widget.item.filename)
        : widget.item.type;

    final isText =
        resolvedMimeType.startsWith('text/') ||
        resolvedMimeType.contains('json') ||
        resolvedMimeType.contains('javascript') ||
        resolvedMimeType.contains('xml');
    final isMarkdown =
        resolvedMimeType == 'text/markdown' ||
        widget.item.filename.endsWith('.md');
    final isImage = resolvedMimeType.startsWith('image/');

    return ResponsiveAlertDialog(
      title: Text(
        widget.item.filename,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      content: SizedBox(
        width: 600,
        height: 400,
        child: _downloadFuture == null
            ? _buildNoPreview(theme, resolvedMimeType)
            : FutureBuilder<Uint8List>(
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
                    return InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 5.0,
                      child: Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(bytes, fit: BoxFit.contain),
                        ),
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
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant,
                          ),
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

                  return _buildNoPreview(theme, resolvedMimeType);
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

  Widget _buildNoPreview(ThemeData theme, String resolvedMimeType) {
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
            resolvedMimeType,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onOpen();
            },
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open with Tool / App'),
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.secondaryContainer,
              foregroundColor: theme.colorScheme.onSecondaryContainer,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
