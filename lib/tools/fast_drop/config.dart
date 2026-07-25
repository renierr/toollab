import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/theme/theme.dart';

import 'fast_drop_p2p_state.dart';
import 'fast_drop_page.dart';
import 'fast_drop_state.dart';

class FastDropTool {
  FastDropTool._();

  static ToolModel get config => ToolModel(
    id: 'fast-drop',
    name: 'Fast Drop',
    description:
        'Quickly drop files or paste clipboard data to the server for temporary storage and sharing',
    icon: Icons.cloud_upload_outlined,
    route: '/fast-drop',
    accentColor: AppTheme.accentTeal,
    sectionId: 'utilities',
    nameL10n: (l10n) => l10n.toolNameFastDrop,
    descriptionL10n: (l10n) => l10n.toolDescFastDrop,
    shareTarget: ShareTargetConfig(accept: ['*/*']),
    fileExtensions: const [],
    createPage: (sd) => FastDropPage(sharedData: sd),
    stateProviders: () => [
      ChangeNotifierProvider<FastDropState>(create: (_) => FastDropState()),
      ChangeNotifierProvider<FastDropP2pState>(
        create: (_) => FastDropP2pState(),
      ),
    ],
  );
}
