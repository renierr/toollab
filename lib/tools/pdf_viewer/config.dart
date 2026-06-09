import 'package:flutter/material.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/theme/theme.dart';

class PdfViewerTool {
  PdfViewerTool._();

  static const ToolModel config = ToolModel(
    id: 'pdf-viewer',
    name: 'PDF Viewer',
    description: 'View PDF files fullscreen with ease',
    icon: Icons.picture_as_pdf,
    route: '/pdf-viewer',
    accentColor: AppTheme.accentRed,
    sectionId: 'utilities',
    shareTarget: ShareTargetConfig(accept: ['application/pdf']),
  );
}
