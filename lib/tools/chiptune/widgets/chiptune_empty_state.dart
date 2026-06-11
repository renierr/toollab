import 'package:file_selector/file_selector.dart' show XFile;
import 'package:flutter/material.dart';
import 'package:tool_lab/widgets/file_drop_zone.dart';

import '../chiptune_colors.dart';
import '../config.dart';

/// Initial state shown when no module is loaded: a drop zone plus the
/// archive list (when there are saved modules to pick from).
class ChiptuneEmptyState extends StatelessWidget {
  final ValueChanged<XFile> onFileSelected;
  final Widget? archivePanel;

  const ChiptuneEmptyState({
    super.key,
    required this.onFileSelected,
    this.archivePanel,
  });

  @override
  Widget build(BuildContext context) {
    final hasArchive = archivePanel != null;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FileDropZone(
            compact: hasArchive,
            allowedExtensions: ChiptuneTool.config.fileExtensions,
            typeLabel: 'Tracker module',
            accentColor: ChiptuneColors.accent,
            icon: Icons.music_note_outlined,
            title: 'Drop a tracker module',
            subtitle: 'MOD · XM · IT files',
            onFileSelected: onFileSelected,
          ),
          if (hasArchive) ...[const SizedBox(height: 12), archivePanel!],
        ],
      ),
    );
  }
}
