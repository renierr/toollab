import 'package:flutter/material.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/theme/theme.dart';

import 'pdf_viewer_page.dart';

class PdfViewerTool {
  PdfViewerTool._();

  static ToolModel get config => ToolModel(
    id: 'pdf-viewer',
    name: 'PDF Viewer',
    description: 'View PDF files fullscreen with ease',
    icon: Icons.picture_as_pdf,
    route: '/pdf-viewer',
    accentColor: AppTheme.accentRed,
    sectionId: 'utilities',
    shareTarget: ShareTargetConfig(accept: ['application/pdf']),
    fileExtensions: ['pdf'],
    createPage: (sf) => PdfViewerPage(sharedFile: sf),
  );
}
