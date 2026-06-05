import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:tool_lab/theme/theme.dart';

class PdfDropZone extends StatefulWidget {
  final Function(String path, String name) onFileSelected;

  const PdfDropZone({super.key, required this.onFileSelected});

  @override
  State<PdfDropZone> createState() => _PdfDropZoneState();
}

class _PdfDropZoneState extends State<PdfDropZone> {
  bool _dragging = false;

  Future<void> _pickFile() async {
    const typeGroup = XTypeGroup(
      label: 'PDFs',
      extensions: <String>['pdf'],
      mimeTypes: <String>['application/pdf'],
    );
    try {
      final file = await openFile(acceptedTypeGroups: const [typeGroup]);
      if (file != null) {
        widget.onFileSelected(file.path, file.name);
      }
    } catch (e) {
      debugPrint('[PdfDropZone] Error picking file: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DropTarget(
      onDragDone: (details) {
        if (details.files.isNotEmpty) {
          final file = details.files.first;
          if (file.name.toLowerCase().endsWith('.pdf')) {
            widget.onFileSelected(file.path, file.name);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Only PDF files are supported')),
            );
          }
        }
      },
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      child: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 480,
              height: 320,
              decoration: BoxDecoration(
                color: _dragging
                    ? AppTheme.accentRed.withValues(alpha: 0.1)
                    : theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _dragging
                      ? AppTheme.accentRed
                      : theme.colorScheme.outlineVariant,
                  width: _dragging ? 3 : 2,
                  style: BorderStyle.solid,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: InkWell(
                onTap: _pickFile,
                borderRadius: BorderRadius.circular(24),
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.accentRed.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.cloud_upload_outlined,
                          size: 48,
                          color: AppTheme.accentRed,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Drag & Drop PDF here',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'or click to browse your files',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
