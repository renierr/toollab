import 'package:file_selector/file_selector.dart' show XFile;
import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/file_drop_zone.dart';

import '../config.dart';

class MarkdownOpenView extends StatelessWidget {
  final Color accentColor;
  final ValueChanged<XFile> onFileSelected;

  const MarkdownOpenView({
    super.key,
    required this.accentColor,
    required this.onFileSelected,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return FileDropZone(
      onFileSelected: onFileSelected,
      allowedExtensions: MarkdownViewerTool.config.fileExtensions,
      allowedMimeTypes: const ['text/markdown', 'text/plain'],
      typeLabel: l10n.miscMarkdownTypeLabel,
      accentColor: accentColor,
      title: l10n.miscMarkdownOpenTitle,
      subtitle: l10n.miscMarkdownDropSubtitle,
    );
  }
}
