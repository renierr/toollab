import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart' show XFile;
import 'package:tool_lab/helpers/temp_file_manager.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/file_drop_zone.dart';
import '../config.dart';
import 'retention_selector.dart';

class FastDropUploadPanel extends StatelessWidget {
  final String retention;
  final ValueChanged<String> onRetentionChanged;
  final ValueChanged<List<XFile>> onFilesSelected;
  final VoidCallback onPasteClipboard;
  final bool isActionsEnabled;
  final TempFileScope tempScope;

  /// Whether the scroll viewport hosting this panel is too short for the tall
  /// drop zone. The panel scrolls, so it cannot measure that itself.
  final bool shortViewport;

  const FastDropUploadPanel({
    super.key,
    required this.retention,
    required this.onRetentionChanged,
    required this.onFilesSelected,
    required this.onPasteClipboard,
    required this.isActionsEnabled,
    required this.tempScope,
    required this.shortViewport,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isAndroid = Platform.isAndroid;
    final useCompact = isAndroid || shortViewport;

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
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: useCompact ? 140 : 240),
              child: FileDropZone(
                onFilesSelected: onFilesSelected,
                allowedExtensions: FastDropTool.config.fileExtensions,
                typeLabel: l10n.fastDropAllFiles,
                accentColor: FastDropTool.config.accentColor,
                icon: Icons.cloud_upload_outlined,
                title: isAndroid
                    ? l10n.fastDropSelectFilesAndroid
                    : l10n.fastDropDropFilesHere,
                subtitle: l10n.fastDropOrClickToBrowse,
                compact: useCompact,
                multiple: true,
                useAndroidStreamingPicker: true,
                tempScope: tempScope,
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
              label: Text(l10n.fastDropPasteClipboard),
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
