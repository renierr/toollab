import 'package:flutter/material.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/theme/theme.dart';

class ImagesToPdfTool {
  ImagesToPdfTool._();

  static const ToolModel config = ToolModel(
    id: 'images-to-pdf',
    name: 'Images to PDF',
    description: 'Convert multiple images into a single PDF document',
    icon: Icons.collections_bookmark_outlined,
    route: '/images-to-pdf',
    accentColor: AppTheme.accentRed,
    sectionId: 'utilities',
  );
}
