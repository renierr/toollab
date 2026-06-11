import 'package:flutter/material.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/theme/theme.dart';

import 'markdown_viewer_page.dart';

class MarkdownViewerTool {
  MarkdownViewerTool._();

  static ToolModel get config => ToolModel(
    id: 'markdown-viewer',
    name: 'Markdown Viewer',
    description: 'View Markdown files fullscreen with ease',
    icon: Icons.description_outlined,
    route: '/markdown-viewer',
    accentColor: AppTheme.accentAmber,
    sectionId: 'utilities',
    shareTarget: ShareTargetConfig(
      accept: ['text/markdown', 'text/x-markdown', 'text/plain', 'text/*'],
    ),
    fileExtensions: ['md', 'txt', 'markdown'],
    createPage: (sf) => MarkdownViewerToolPage(sharedFile: sf),
  );
}
