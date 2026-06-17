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
    nameL10n: (l10n) => l10n.toolNameMarkdownViewer,
    descriptionL10n: (l10n) => l10n.toolDescMarkdownViewer,
    shareTarget: ShareTargetConfig(
      accept: ['text/markdown', 'text/x-markdown', 'text/plain', 'text/*'],
    ),
    fileExtensions: ['md', 'txt', 'markdown'],
    createPage: (sd) => MarkdownViewerToolPage(sharedFile: sd?.firstFile),
  );
}
