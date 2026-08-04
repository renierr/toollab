import 'dart:io';

import 'package:flutter/material.dart';
import 'package:tool_lab/tools/file_manager/file_manager_entry.dart';
import 'package:tool_lab/tools/file_manager/widgets/file_manager_entry_icon.dart';

/// Hero image preview for the details dialog: keeps the original aspect ratio
/// and decodes at dialog width instead of the list thumbnail size.
class FileManagerDetailsPreview extends StatelessWidget {
  final FileManagerEntry entry;
  final double width;

  const FileManagerDetailsPreview({
    super.key,
    required this.entry,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 140, maxHeight: 260),
        color: theme.colorScheme.surfaceContainerHighest,
        child: Image.file(
          File(entry.path),
          fit: BoxFit.contain,
          cacheWidth: (width * devicePixelRatio).round(),
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, _, _) => Center(
            child: FileManagerEntryIcon(
              entry: entry,
              size: 42,
              showPreview: false,
            ),
          ),
        ),
      ),
    );
  }
}
