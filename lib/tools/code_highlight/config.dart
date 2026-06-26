import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/theme/theme.dart';

import 'code_highlight_page.dart';
import 'code_highlight_state.dart';

class CodeHighlightTool {
  CodeHighlightTool._();

  static ToolModel get config => ToolModel(
    id: 'code-highlight',
    name: 'Code Highlight & Edit',
    description: 'Highlight syntax and edit code files',
    icon: Icons.code_outlined,
    route: '/code-highlight',
    accentColor: AppTheme.accentBlue,
    sectionId: 'utilities',
    nameL10n: (l10n) => l10n.toolNameCodeHighlight,
    descriptionL10n: (l10n) => l10n.toolDescCodeHighlight,
    stateProviders: () => [
      ChangeNotifierProvider<CodeHighlightState>(
        create: (_) => CodeHighlightState(),
      ),
    ],
    shareTarget: ShareTargetConfig(
      accept: [
        'text/plain',
        'text/javascript',
        'text/x-python',
        'text/x-dart',
        'text/html',
        'text/css',
        'text/yaml',
        'application/json',
        'application/javascript',
        'application/x-javascript',
        'text/*',
      ],
    ),
    fileExtensions: [
      'txt',
      'dart',
      'py',
      'json',
      'yaml',
      'yml',
      'md',
      'markdown',
      'js',
      'ts',
      'html',
      'css',
      'go',
      'rs',
      'sql',
      'java',
      'kt',
      'swift',
    ],
    createPage: (sd) => CodeHighlightToolPage(sharedFile: sd?.firstFile),
  );
}
