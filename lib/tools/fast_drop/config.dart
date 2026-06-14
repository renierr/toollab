import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/theme/theme.dart';

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
    shareTarget: ShareTargetConfig(accept: ['*/*']),
    fileExtensions: const [],
    createPage: (sf) => FastDropPage(sharedFile: sf),
    stateProviders: () => [
      ChangeNotifierProvider<FastDropState>(create: (_) => FastDropState()),
    ],
  );
}
