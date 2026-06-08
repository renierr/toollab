import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';

class FileDropZone extends StatefulWidget {
  final ValueChanged<XFile> onFileSelected;
  final List<String> allowedExtensions;
  final List<String>? allowedMimeTypes;
  final String typeLabel;
  final Color accentColor;
  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final IconData buttonIcon;
  final List<Widget>? extraButtons;
  final bool compact;

  const FileDropZone({
    super.key,
    required this.onFileSelected,
    required this.allowedExtensions,
    required this.typeLabel,
    required this.accentColor,
    required this.title,
    required this.subtitle,
    this.allowedMimeTypes,
    this.icon = Icons.description_outlined,
    this.buttonLabel = 'Browse Files',
    this.buttonIcon = Icons.folder_open,
    this.extraButtons,
    this.compact = false,
  });

  @override
  State<FileDropZone> createState() => _FileDropZoneState();
}

class _FileDropZoneState extends State<FileDropZone> {
  bool _dragging = false;

  Future<void> _pickFile() async {
    try {
      final hasFilters =
          widget.allowedExtensions.isNotEmpty ||
          widget.allowedMimeTypes != null;
      final typeGroup = XTypeGroup(
        label: widget.typeLabel,
        extensions: widget.allowedExtensions.isNotEmpty
            ? widget.allowedExtensions
            : null,
        mimeTypes: widget.allowedMimeTypes,
      );
      final file = await openFile(
        acceptedTypeGroups: hasFilters ? [typeGroup] : const <XTypeGroup>[],
      );
      if (file != null && mounted) {
        widget.onFileSelected(file);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to select file: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DropTarget(
      onDragDone: (details) {
        setState(() => _dragging = false);
        if (details.files.isNotEmpty) {
          final file = details.files.first;
          final name = file.name.toLowerCase();
          bool isValid = widget.allowedExtensions.isEmpty;
          if (!isValid) {
            for (final ext in widget.allowedExtensions) {
              if (name.endsWith('.${ext.toLowerCase()}')) {
                isValid = true;
                break;
              }
            }
          }
          if (isValid) {
            widget.onFileSelected(file);
          } else {
            if (mounted) {
              final extensionsStr = widget.allowedExtensions
                  .map((e) => '.$e')
                  .join(' or ');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Only $extensionsStr files are supported'),
                ),
              );
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
            color: _dragging ? widget.accentColor : Colors.transparent,
            width: 3,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: widget.compact
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        widget.icon,
                        size: 40,
                        color: widget.accentColor.withValues(alpha: 0.6),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _pickFile,
                        icon: Icon(widget.buttonIcon, size: 16),
                        label: Text(widget.buttonLabel),
                        style: FilledButton.styleFrom(
                          backgroundColor: widget.accentColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      if (widget.extraButtons != null) ...widget.extraButtons!,
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        widget.icon,
                        size: 80,
                        color: widget.accentColor.withValues(alpha: 0.6),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        widget.title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.5,
                          ),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      FilledButton.icon(
                        onPressed: _pickFile,
                        icon: Icon(widget.buttonIcon),
                        label: Text(widget.buttonLabel),
                        style: FilledButton.styleFrom(
                          backgroundColor: widget.accentColor,
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
                      if (widget.extraButtons != null) ...widget.extraButtons!,
                      if (_dragging)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text(
                            'Release to load file',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: widget.accentColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
