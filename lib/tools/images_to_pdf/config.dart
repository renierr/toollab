import 'package:flutter/material.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/theme/theme.dart';

import 'images_to_pdf_page.dart';

class ImagesToPdfTool {
  ImagesToPdfTool._();

  static ToolModel get config => ToolModel(
    id: 'images-to-pdf',
    name: 'Images to PDF',
    description: 'Convert multiple images into a single PDF document',
    icon: Icons.collections_bookmark_outlined,
    route: '/images-to-pdf',
    accentColor: AppTheme.accentRed,
    sectionId: 'utilities',
    nameL10n: (l10n) => l10n.toolNameImagesToPdf,
    descriptionL10n: (l10n) => l10n.toolDescImagesToPdf,
    fileExtensions: ['png', 'jpg', 'jpeg', 'gif', 'bmp', 'webp', 'svg'],
    createPage: (_) => const ImagesToPdfPage(),
  );
}
