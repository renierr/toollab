import 'dart:io';
import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';

class MarkdownDropZone extends StatefulWidget {
  final Widget child;
  final Future<void> Function(File file, String name) onFileDropped;

  const MarkdownDropZone({
    super.key,
    required this.child,
    required this.onFileDropped,
  });

  @override
  State<MarkdownDropZone> createState() => _MarkdownDropZoneState();
}

class _MarkdownDropZoneState extends State<MarkdownDropZone> {
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return DropTarget(
      onDragDone: (details) async {
        setState(() => _dragging = false);
        if (details.files.isNotEmpty) {
          for (final file in details.files) {
            final name = file.name.toLowerCase();
            if (name.endsWith('.md') || name.endsWith('.txt')) {
              await widget.onFileDropped(File(file.path), file.name);
            } else {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.notesDropZoneUnsupportedFile)),
                );
              }
            }
          }
        }
      },
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      child: Stack(
        children: [
          widget.child,
          if (_dragging)
            Container(
              color: theme.colorScheme.surface.withValues(alpha: 0.8),
              child: Center(
                child: Container(
                  width: 320,
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppTheme.accentTeal,
                      width: 3,
                      style: BorderStyle.solid,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    color: AppTheme.accentTeal.withValues(alpha: 0.1),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.cloud_upload_outlined,
                        size: 64,
                        color: AppTheme.accentTeal,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.notesDropZoneTitle,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.accentTeal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
