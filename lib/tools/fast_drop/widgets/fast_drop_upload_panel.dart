import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart' show XFile;
import 'package:tool_lab/widgets/file_drop_zone.dart';
import 'package:tool_lab/theme/theme.dart';
import '../config.dart';
import 'retention_selector.dart';

class FastDropUploadPanel extends StatelessWidget {
  final String retention;
  final ValueChanged<String> onRetentionChanged;
  final ValueChanged<XFile> onFileSelected;
  final VoidCallback onPasteClipboard;
  final bool isActionsEnabled;

  const FastDropUploadPanel({
    super.key,
    required this.retention,
    required this.onRetentionChanged,
    required this.onFileSelected,
    required this.onPasteClipboard,
    required this.isActionsEnabled,
  });

  @override
  Widget build(BuildContext context) {
    final isAndroid = Platform.isAndroid;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RetentionSelector(
          selectedValue: retention,
          onChanged: onRetentionChanged,
        ),
        const SizedBox(height: 16),
        Opacity(
          opacity: isActionsEnabled ? 1.0 : 0.5,
          child: AbsorbPointer(
            absorbing: !isActionsEnabled,
            child: SizedBox(
              height: isAndroid ? 160 : 290,
              child: FileDropZone(
                onFileSelected: onFileSelected,
                allowedExtensions: FastDropTool.config.fileExtensions,
                typeLabel: 'All Files',
                accentColor: FastDropTool.config.accentColor,
                icon: Icons.cloud_upload_outlined,
                title: isAndroid
                    ? 'Select a file to upload'
                    : 'Drop files here',
                subtitle: 'or click to browse',
                compact: isAndroid,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: isActionsEnabled ? onPasteClipboard : null,
              icon: const Icon(Icons.paste_outlined),
              label: const Text('Paste Clipboard'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.accentTeal,
                side: const BorderSide(color: AppTheme.accentTeal),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
