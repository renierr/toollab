import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/helpers/mime_type_helper.dart';
import 'package:tool_lab/helpers/temp_file_manager.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/markdown_view.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';
import '../fast_drop_model.dart';

class FastDropPreviewDialog extends StatefulWidget {
  final FastDropItem item;
  final Future<String> Function(String id, String outputPath) onDownloadToFile;
  final VoidCallback onOpen;
  final VoidCallback onSave;

  const FastDropPreviewDialog({
    super.key,
    required this.item,
    required this.onDownloadToFile,
    required this.onOpen,
    required this.onSave,
  });

  @override
  State<FastDropPreviewDialog> createState() => _FastDropPreviewDialogState();
}

class _FastDropPreviewDialogState extends State<FastDropPreviewDialog>
    with DisposeCleanup {
  late final TempFileScope _scope = TempFileManager.createScope();
  Future<String>? _downloadFuture;

  bool get _isPreviewable {
    if (widget.item.size > 10 * 1024 * 1024) return false;

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
    onDispose(() => _scope.cleanTracked());
    if (_isPreviewable) {
      _downloadFuture = _startDownload();
    }
  }

  Future<String> _startDownload() async {
    final tempPath = await _scope.createFile(
      'fast_drop_preview_${widget.item.id}',
    );
    await widget.onDownloadToFile(widget.item.id, tempPath);
    return tempPath;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
      title: Text(widget.item.filename.split('').join('\u{200B}')),
      content: SizedBox(
        width: 600,
        height: 400,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.item.description != null &&
                  widget.item.description!.trim().isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.5,
                      ),
                    ),
                  ),
                  child: Text(
                    widget.item.description!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              if (_downloadFuture == null)
                _NoPreviewPlaceholder(
                  mimeType: resolvedMimeType,
                  onOpen: _openExternally,
                )
              else
                FutureBuilder<String>(
                  future: _downloadFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(
                              color: AppTheme.accentTeal,
                            ),
                            const SizedBox(height: 16),
                            Text(l10n.fastDropDownloadingForPreview),
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
                              l10n.fastDropPreviewFailed(
                                snapshot.error.toString(),
                              ),
                              textAlign: TextAlign.center,
                              style: TextStyle(color: theme.colorScheme.error),
                            ),
                          ],
                        ),
                      );
                    }

                    final path = snapshot.data!;
                    if (isImage) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: InteractiveViewer(
                            minScale: 0.5,
                            maxScale: 5.0,
                            child: Image.file(File(path), fit: BoxFit.contain),
                          ),
                        ),
                      );
                    }

                    if (isText) {
                      return FutureBuilder<String>(
                        future: File(path).readAsString(encoding: utf8),
                        builder: (context, textSnapshot) {
                          if (textSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(
                                color: AppTheme.accentTeal,
                              ),
                            );
                          }
                          if (textSnapshot.hasError) {
                            return Text(
                              l10n.fastDropReadFileFailed(
                                textSnapshot.error.toString(),
                              ),
                              style: TextStyle(color: theme.colorScheme.error),
                            );
                          }
                          final text = textSnapshot.data ?? '';
                          if (isMarkdown) {
                            return MarkdownView(
                              data: text,
                              accentColor: AppTheme.accentTeal,
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
                              child: SelectableText(
                                text,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                ),
                              ),
                            );
                          }
                        },
                      );
                    }

                    return _NoPreviewPlaceholder(
                      mimeType: resolvedMimeType,
                      onOpen: _openExternally,
                    );
                  },
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonClose),
        ),
        FilledButton.icon(
          onPressed: () {
            Navigator.of(context).pop();
            widget.onOpen();
          },
          icon: const Icon(Icons.open_in_new),
          label: Text(l10n.fastDropOpenShare),
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
          label: Text(l10n.fastDropDownload),
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.accentTeal,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  void _openExternally() {
    Navigator.of(context).pop();
    widget.onOpen();
  }
}

class _NoPreviewPlaceholder extends StatelessWidget {
  final String mimeType;
  final VoidCallback onOpen;

  const _NoPreviewPlaceholder({required this.mimeType, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

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
          Text(
            l10n.fastDropPreviewNotAvailable,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            mimeType,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onOpen,
            icon: const Icon(Icons.open_in_new),
            label: Text(l10n.fastDropOpenWithApp),
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
