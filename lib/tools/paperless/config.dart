import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/theme/theme.dart';

import 'paperless_page.dart';
import 'paperless_state.dart';

class PaperlessTool {
  PaperlessTool._();

  /// What paperless consumes without the optional Tika/Gotenberg services.
  static const List<String> uploadMimeTypes = [
    'application/pdf',
    'image/png',
    'image/jpeg',
    'image/tiff',
    'image/gif',
    'image/webp',
  ];

  static const List<String> uploadExtensions = [
    'pdf',
    'png',
    'jpg',
    'jpeg',
    'tif',
    'tiff',
    'gif',
    'webp',
  ];

  static ToolModel get config => ToolModel(
    id: 'paperless',
    name: 'Paperless',
    description: 'Browse, search and upload documents on your Paperless server',
    icon: Icons.inventory_2_outlined,
    route: '/paperless',
    accentColor: AppTheme.accentTeal,
    sectionId: 'utilities',
    nameL10n: (l10n) => l10n.toolNamePaperless,
    descriptionL10n: (l10n) => l10n.toolDescPaperless,
    shareTarget: const ShareTargetConfig(accept: uploadMimeTypes),
    fileExtensions: uploadExtensions,
    createPage: (sd) => PaperlessPage(sharedData: sd),
    stateProviders: () => [
      ChangeNotifierProvider<PaperlessState>(create: (_) => PaperlessState()),
    ],
  );
}
