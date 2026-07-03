import 'package:file_selector/file_selector.dart' show XFile;
import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/file_drop_zone.dart';

import '../chiptune_colors.dart';
import '../config.dart';

/// Initial state shown when no module is loaded: a multi-file drop zone plus
/// the archive list (when there are saved modules to pick from).
class ChiptuneEmptyState extends StatelessWidget {
  final ValueChanged<List<XFile>> onFilesSelected;

  /// Desktop-only whole-folder action; null hides the button.
  final VoidCallback? onPickFolder;
  final Widget? archivePanel;

  const ChiptuneEmptyState({
    super.key,
    required this.onFilesSelected,
    this.onPickFolder,
    this.archivePanel,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasArchive = archivePanel != null;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FileDropZone(
            compact: hasArchive,
            multiple: true,
            allowedExtensions: ChiptuneTool.config.fileExtensions,
            typeLabel: l10n.chipEmptyTypeLabel,
            accentColor: ChiptuneColors.accent,
            icon: Icons.music_note_outlined,
            title: l10n.chipEmptyDropTitle,
            subtitle: l10n.chipEmptyDropSubtitle,
            onFilesSelected: onFilesSelected,
          ),
          if (onPickFolder != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onPickFolder,
              icon: const Icon(Icons.folder_special_outlined),
              label: Text(l10n.chipFolderTooltip),
            ),
          ],
          if (hasArchive) ...[const SizedBox(height: 12), archivePanel!],
        ],
      ),
    );
  }
}
