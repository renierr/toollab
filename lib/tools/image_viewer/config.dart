import 'package:flutter/material.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/theme/theme.dart';

class ImageViewerTool {
  ImageViewerTool._();

  static const ToolModel config = ToolModel(
    id: 'image-viewer',
    name: 'Image Viewer',
    description: 'View, zoom, resize, and convert image formats',
    icon: Icons.image_outlined,
    route: '/image-viewer',
    accentColor: AppTheme.accentBlue,
    sectionId: 'utilities',
    fullscreen: true,
    shareTarget: ShareTargetConfig(accept: ['image/*']),
  );
}
