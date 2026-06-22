import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/theme/theme.dart';

import 'doc_format.dart';
import 'file_converter_page.dart';
import 'file_converter_state.dart';

class FileConverterTool {
  FileConverterTool._();

  static ToolModel get config => ToolModel(
    id: 'file-converter',
    name: 'File Converter',
    description: 'Convert documents between DOCX, PDF, HTML, Markdown and text',
    icon: Icons.sync_alt,
    route: '/file-converter',
    accentColor: AppTheme.accentTeal,
    sectionId: 'utilities',
    nameL10n: (l10n) => l10n.toolNameFileConverter,
    descriptionL10n: (l10n) => l10n.toolDescFileConverter,
    fileExtensions: DocFormat.allExtensions,
    shareTarget: const ShareTargetConfig(accept: ['*/*']),
    createPage: (sd) => FileConverterPage(sharedFile: sd?.firstFile),
    stateProviders: () => [
      ChangeNotifierProvider<FileConverterState>(
        create: (_) => FileConverterState(),
      ),
    ],
  );
}
