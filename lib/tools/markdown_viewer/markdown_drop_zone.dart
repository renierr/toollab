import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:tool_lab/tools/markdown_viewer/config.dart';

class MarkdownDropZone extends StatefulWidget {
  final ValueChanged<String> onFileSelected;

  const MarkdownDropZone({super.key, required this.onFileSelected});

  @override
  State<MarkdownDropZone> createState() => _MarkdownDropZoneState();
}

class _MarkdownDropZoneState extends State<MarkdownDropZone> {
  bool _dragging = false;

  Future<void> _pickFile() async {
    final typeGroup = XTypeGroup(
      label: 'Markdown',
      extensions: ['md', 'txt', 'markdown'],
      mimeTypes: const ['text/markdown', 'text/plain'],
    );
    final result = await openFiles(acceptedTypeGroups: [typeGroup]);
    if (result.isNotEmpty) {
      final file = result.first;
      final bytes = await file.readAsBytes();
      final content = utf8.decode(bytes);
      if (mounted) {
        widget.onFileSelected(content);
      }
    }
  }

  Future<void> _handleDropFile(dynamic dropFile) async {
    try {
      final bytes = await dropFile.readAsBytes();
      final content = utf8.decode(bytes);
      if (mounted) {
        widget.onFileSelected(content);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to read file: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = MarkdownViewerTool.config.accentColor;

    return DropTarget(
      onDragDone: (details) async {
        setState(() => _dragging = false);
        if (details.files.isNotEmpty) {
          for (final file in details.files) {
            final name = file.name.toLowerCase();
            if (name.endsWith('.md') ||
                name.endsWith('.txt') ||
                name.endsWith('.markdown')) {
              await _handleDropFile(file);
            } else {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Only Markdown (.md) or Text (.txt) files are supported',
                    ),
                  ),
                );
              }
            }
          }
        }
      },
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          border: Border.all(
            color: _dragging ? accent : Colors.transparent,
            width: 3,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.description_outlined,
                size: 80,
                color: accent.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 24),
              Text(
                'Open a Markdown File',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Drag & drop a .md or .txt file here',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.folder_open),
                label: const Text('Browse Files'),
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              if (_dragging)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    'Release to load file',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
