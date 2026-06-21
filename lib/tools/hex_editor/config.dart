import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/theme/theme.dart';

import 'hex_editor_page.dart';
import 'hex_editor_state.dart';

class HexEditorTool {
  HexEditorTool._();

  static ToolModel get config => ToolModel(
    id: 'hex-editor',
    name: 'Hex Editor',
    description: 'Inspect and edit files in hexadecimal and ASCII views',
    icon: Icons.developer_mode,
    route: '/hex-editor',
    accentColor: AppTheme.accentPurple,
    sectionId: 'utilities',
    nameL10n: (l10n) => l10n.toolNameHexEditor,
    descriptionL10n: (l10n) => l10n.toolDescHexEditor,
    shareTarget: const ShareTargetConfig(accept: ['*/*']),
    createPage: (sd) => HexEditorPage(sharedFile: sd?.firstFile),
    stateProviders: () => [
      ChangeNotifierProvider<HexEditorState>(create: (_) => HexEditorState()),
    ],
  );
}
