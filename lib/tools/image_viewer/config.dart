import 'package:flutter/material.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/theme/theme.dart';

import 'image_viewer_page.dart';

/// Displayable extensions; AVIF/HEIC only decode on Android.
const List<String> imageViewerExtensions = [
  'png',
  'jpg',
  'jpeg',
  'gif',
  'bmp',
  'webp',
  'tif',
  'tiff',
  'ico',
  'tga',
  'ppm',
  'pgm',
  'pbm',
  'pnm',
  'avif',
  'heic',
  'heif',
];

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
    nameL10n: (l10n) => l10n.toolNameImageViewer,
    descriptionL10n: (l10n) => l10n.toolDescImageViewer,
    shareTarget: ShareTargetConfig(accept: ['image/*']),
    fileExtensions: imageViewerExtensions,
    createPage: (sd) => ImageViewerPage(sharedFile: sd?.firstFile),
  );
}
