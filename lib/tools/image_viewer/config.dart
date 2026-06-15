import 'package:flutter/material.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/theme/theme.dart';

import 'image_viewer_page.dart';

class ImageViewerTool {
  ImageViewerTool._();

  static ToolModel get config => ToolModel(
    id: 'image-viewer',
    name: 'Image Viewer',
    description: 'View, zoom, resize, and convert image formats',
    icon: Icons.image_outlined,
    route: '/image-viewer',
    accentColor: AppTheme.accentBlue,
    sectionId: 'utilities',
    shareTarget: ShareTargetConfig(accept: ['image/*']),
    fileExtensions: ['png', 'jpg', 'jpeg', 'gif', 'bmp', 'webp', 'svg'],
    createPage: (sd) => ImageViewerPage(sharedFile: sd?.firstFile),
  );
}
